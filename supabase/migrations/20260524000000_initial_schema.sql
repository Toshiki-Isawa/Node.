-- Node. schema — plants, observations, growth_logs

create extension if not exists "pgcrypto";

create table if not exists public.plants (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    species text,
    category text,
    acquired_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.observations (
    id uuid primary key default gen_random_uuid(),
    plant_id uuid not null references public.plants(id) on delete cascade,
    image_url text,
    note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    sync_status text not null default 'local_only'
        check (sync_status in ('local_only', 'syncing', 'synced', 'failed'))
);

create table if not exists public.growth_logs (
    id uuid primary key default gen_random_uuid(),
    plant_id uuid not null references public.plants(id) on delete cascade,
    type text not null,
    memo text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.timelapse_jobs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    plant_id uuid not null references public.plants(id) on delete cascade,
    observation_ids uuid[] not null,
    status text not null default 'pending'
        check (status in ('pending', 'processing', 'completed', 'failed')),
    output_url text,
    error text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.plants enable row level security;
alter table public.observations enable row level security;
alter table public.growth_logs enable row level security;
alter table public.timelapse_jobs enable row level security;

create policy "plants_select_own" on public.plants
    for select using (auth.uid() = user_id);
create policy "plants_insert_own" on public.plants
    for insert with check (auth.uid() = user_id);
create policy "plants_update_own" on public.plants
    for update using (auth.uid() = user_id);
create policy "plants_delete_own" on public.plants
    for delete using (auth.uid() = user_id);

create policy "observations_select_own" on public.observations
    for select using (
        exists (
            select 1 from public.plants p
            where p.id = observations.plant_id and p.user_id = auth.uid()
        )
    );
create policy "observations_insert_own" on public.observations
    for insert with check (
        exists (
            select 1 from public.plants p
            where p.id = observations.plant_id and p.user_id = auth.uid()
        )
    );
create policy "observations_update_own" on public.observations
    for update using (
        exists (
            select 1 from public.plants p
            where p.id = observations.plant_id and p.user_id = auth.uid()
        )
    );
create policy "observations_delete_own" on public.observations
    for delete using (
        exists (
            select 1 from public.plants p
            where p.id = observations.plant_id and p.user_id = auth.uid()
        )
    );

create policy "growth_logs_select_own" on public.growth_logs
    for select using (
        exists (
            select 1 from public.plants p
            where p.id = growth_logs.plant_id and p.user_id = auth.uid()
        )
    );
create policy "growth_logs_insert_own" on public.growth_logs
    for insert with check (
        exists (
            select 1 from public.plants p
            where p.id = growth_logs.plant_id and p.user_id = auth.uid()
        )
    );
create policy "growth_logs_update_own" on public.growth_logs
    for update using (
        exists (
            select 1 from public.plants p
            where p.id = growth_logs.plant_id and p.user_id = auth.uid()
        )
    );
create policy "growth_logs_delete_own" on public.growth_logs
    for delete using (
        exists (
            select 1 from public.plants p
            where p.id = growth_logs.plant_id and p.user_id = auth.uid()
        )
    );

create policy "timelapse_jobs_select_own" on public.timelapse_jobs
    for select using (auth.uid() = user_id);
create policy "timelapse_jobs_insert_own" on public.timelapse_jobs
    for insert with check (auth.uid() = user_id);
create policy "timelapse_jobs_update_own" on public.timelapse_jobs
    for update using (auth.uid() = user_id);

create index if not exists idx_plants_user_id on public.plants(user_id);
create index if not exists idx_observations_plant_id on public.observations(plant_id);
create index if not exists idx_growth_logs_plant_id on public.growth_logs(plant_id);
