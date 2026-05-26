-- plants にメモ（任意）を追加

alter table public.plants
    add column if not exists note text;
