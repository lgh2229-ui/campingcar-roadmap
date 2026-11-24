-- Idempotent schema for manually verified dining-score and business hours.
alter table public.diningcode_restaurants
  add column if not exists opening_hours text,
  add column if not exists hours_source_url text,
  add column if not exists hours_checked_at timestamptz;
comment on column public.diningcode_restaurants.opening_hours is
  'OSM-style weekly business schedule; status is an estimate, not live occupancy or holiday verification.';
comment on column public.diningcode_restaurants.hours_source_url is
  'Public source for last-verified regular opening hours.';
