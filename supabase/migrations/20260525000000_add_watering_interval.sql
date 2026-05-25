-- plants に水やり頻度（日数）を追加

alter table public.plants
    add column if not exists watering_interval_days integer
        check (watering_interval_days is null or watering_interval_days > 0);
