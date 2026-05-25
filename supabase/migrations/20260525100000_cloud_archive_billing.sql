-- Cloud sync & archive billing: Seed / Archive / Conservatory

create table if not exists public.user_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    plan text not null default 'seed'
        check (plan in ('seed', 'archive', 'conservatory')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.storage_objects (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    observation_id uuid references public.observations(id) on delete set null,
    object_key text not null unique,
    byte_size bigint not null check (byte_size > 0),
    content_type text not null default 'image/jpeg',
    created_at timestamptz not null default now()
);

create table if not exists public.subscription_entitlements (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    product_id text not null,
    transaction_id text not null unique,
    original_transaction_id text not null,
    expires_at timestamptz,
    environment text not null default 'production'
        check (environment in ('production', 'sandbox', 'xcode')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.observations
    drop constraint if exists observations_sync_status_check;

alter table public.observations
    add constraint observations_sync_status_check
    check (sync_status in (
        'local_only',
        'syncing',
        'synced',
        'failed',
        'sync_paused_storage_limit'
    ));

create index if not exists idx_storage_objects_user_id on public.storage_objects(user_id);
create index if not exists idx_storage_objects_observation_id on public.storage_objects(observation_id);
create index if not exists idx_subscription_entitlements_user_id
    on public.subscription_entitlements(user_id);
create index if not exists idx_subscription_entitlements_original_tx
    on public.subscription_entitlements(original_transaction_id);

alter table public.user_profiles enable row level security;
alter table public.storage_objects enable row level security;
alter table public.subscription_entitlements enable row level security;

create policy "user_profiles_select_own" on public.user_profiles
    for select using (auth.uid() = user_id);

create policy "storage_objects_select_own" on public.storage_objects
    for select using (auth.uid() = user_id);

create policy "storage_objects_insert_own" on public.storage_objects
    for insert with check (auth.uid() = user_id);

create policy "storage_objects_update_own" on public.storage_objects
    for update using (auth.uid() = user_id);

create policy "subscription_entitlements_select_own" on public.subscription_entitlements
    for select using (auth.uid() = user_id);

create or replace function public.get_storage_usage_bytes(p_user_id uuid default auth.uid())
returns bigint
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(sum(byte_size), 0)::bigint
    from public.storage_objects
    where user_id = p_user_id;
$$;

create or replace function public.resolve_plan_from_product(p_product_id text)
returns text
language sql
immutable
as $$
    select case
        when p_product_id = 'app.node.conservatory.monthly' then 'conservatory'
        when p_product_id = 'app.node.archive.monthly' then 'archive'
        else null
    end;
$$;

create or replace function public.get_user_plan(p_user_id uuid default auth.uid())
returns text
language sql
stable
security definer
set search_path = public
as $$
    with active_entitlements as (
        select resolve_plan_from_product(product_id) as resolved_plan
        from public.subscription_entitlements
        where user_id = p_user_id
          and (expires_at is null or expires_at > now())
          and resolve_plan_from_product(product_id) is not null
    )
    select coalesce(
        (
            select resolved_plan
            from active_entitlements
            order by case resolved_plan
                when 'conservatory' then 2
                when 'archive' then 1
                else 0
            end desc
            limit 1
        ),
        (
            select up.plan
            from public.user_profiles up
            where up.user_id = p_user_id
        ),
        'seed'
    );
$$;

revoke all on function public.get_storage_usage_bytes(uuid) from public;
grant execute on function public.get_storage_usage_bytes(uuid) to authenticated;
revoke all on function public.get_user_plan(uuid) from public;
grant execute on function public.get_user_plan(uuid) to authenticated;

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.user_profiles (user_id, plan)
    values (new.id, 'seed')
    on conflict (user_id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
    after insert on auth.users
    for each row execute function public.handle_new_user_profile();

create or replace function public.cleanup_storage_object_on_observation_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.storage_objects where observation_id = old.id;
    return old;
end;
$$;

drop trigger if exists on_observation_deleted_storage on public.observations;
create trigger on_observation_deleted_storage
    before delete on public.observations
    for each row execute function public.cleanup_storage_object_on_observation_delete();
