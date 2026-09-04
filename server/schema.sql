-- 캠핑카족 로드맵 V2 / Supabase 초기 스키마
-- Supabase SQL Editor에서 한 번 실행합니다.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  phone text not null default '',
  phone_verified boolean not null default false,
  role text not null default 'user' check (role in ('user','admin')),
  vehicle_status text not null default '',
  vehicle_name text not null default '',
  vehicle_height_mm integer,
  sanitation_type text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint administrator_reserved check (lower(username) <> 'administrator' or role = 'admin')
);
create unique index if not exists profiles_username_lower_uq on public.profiles(lower(username));
create unique index if not exists profiles_phone_uq on public.profiles(phone) where phone <> '';

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and lower(username) = 'administrator'
  );
$$;

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 100),
  latitude double precision not null,
  longitude double precision not null,
  address text not null default '',
  services text[] not null default '{}',
  prices jsonb not null default '{}'::jsonb,
  hours text not null default '',
  reservation text not null default '',
  max_height_mm integer,
  inquiry_phone text not null default '',
  note text not null default '',
  status text not null default 'ok' check (status in ('ok','change','bad')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint places_services_allowed check (services <@ array['급수','블랙탱크 비움','노지/차박','공중화장실']::text[])
);
create index if not exists places_lat_lng_idx on public.places(latitude, longitude);
create index if not exists places_created_at_idx on public.places(created_at desc);

create table if not exists public.place_photos (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  uploader_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  public_url text not null,
  created_at timestamptz not null default now()
);
create index if not exists place_photos_place_idx on public.place_photos(place_id);

create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, place_id)
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null default '',
  status text not null check (status in ('ok','change','bad')),
  body text not null default '' check (char_length(body) <= 200),
  created_at timestamptz not null default now()
);
create index if not exists reviews_place_created_idx on public.reviews(place_id, created_at desc);

create or replace function public.fill_review_author_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select username into new.author_name from public.profiles where id = new.author_id;
  return new;
end $$;

drop trigger if exists trg_review_author_name on public.reviews;
create trigger trg_review_author_name before insert on public.reviews
for each row execute function public.fill_review_author_name();

create or replace function public.sync_place_status_from_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.places set status = new.status, updated_at = now() where id = new.place_id;
  return new;
end $$;

drop trigger if exists trg_review_status on public.reviews;
create trigger trg_review_status after insert on public.reviews
for each row execute function public.sync_place_status_from_review();

-- 사진 URL까지 한 번에 읽기 위한 뷰
create or replace view public.places_view
with (security_invoker = true)
as
select p.*,
  coalesce((select jsonb_agg(pp.public_url order by pp.created_at) from public.place_photos pp where pp.place_id = p.id), '[]'::jsonb) as photo_urls
from public.places p;

create or replace view public.reviews_view
with (security_invoker = true)
as
select id, place_id, author_id, author_name, status, body, created_at
from public.reviews;

-- RLS
alter table public.profiles enable row level security;
alter table public.places enable row level security;
alter table public.place_photos enable row level security;
alter table public.favorites enable row level security;
alter table public.reviews enable row level security;

-- profiles: 본인만 조회/등록/수정. role은 별도 column privilege로 차단.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id = auth.uid() and role = 'user');
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

revoke update on public.profiles from authenticated;
grant update (username, phone, phone_verified, vehicle_status, vehicle_name, vehicle_height_mm, sanitation_type, updated_at) on public.profiles to authenticated;

-- places: 로그인 회원 전체 조회, 인증된 회원 등록, 수정/삭제는 관리자만.
drop policy if exists places_select_authenticated on public.places;
create policy places_select_authenticated on public.places for select to authenticated using (true);
drop policy if exists places_insert_verified on public.places;
create policy places_insert_verified on public.places for insert to authenticated
with check (
  owner_id = auth.uid()
  and exists(select 1 from public.profiles pr where pr.id = auth.uid() and pr.phone_verified = true)
);
drop policy if exists places_update_admin on public.places;
create policy places_update_admin on public.places for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists places_delete_admin on public.places;
create policy places_delete_admin on public.places for delete to authenticated using (public.is_admin());

-- place photos
drop policy if exists place_photos_select_authenticated on public.place_photos;
create policy place_photos_select_authenticated on public.place_photos for select to authenticated using (true);
drop policy if exists place_photos_insert_own on public.place_photos;
create policy place_photos_insert_own on public.place_photos for insert to authenticated with check (uploader_id = auth.uid());
drop policy if exists place_photos_delete_admin on public.place_photos;
create policy place_photos_delete_admin on public.place_photos for delete to authenticated using (public.is_admin());

-- favorites
drop policy if exists favorites_own_all on public.favorites;
create policy favorites_own_all on public.favorites for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- reviews
drop policy if exists reviews_select_authenticated on public.reviews;
create policy reviews_select_authenticated on public.reviews for select to authenticated using (true);
drop policy if exists reviews_insert_verified on public.reviews;
create policy reviews_insert_verified on public.reviews for insert to authenticated
with check (
  author_id = auth.uid()
  and exists(select 1 from public.profiles pr where pr.id = auth.uid() and pr.phone_verified = true)
);
drop policy if exists reviews_delete_admin on public.reviews;
create policy reviews_delete_admin on public.reviews for delete to authenticated using (public.is_admin());

-- updated_at triggers
drop trigger if exists trg_profiles_touch on public.profiles;
create trigger trg_profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
drop trigger if exists trg_places_touch on public.places;
create trigger trg_places_touch before update on public.places for each row execute function public.touch_updated_at();

-- Storage bucket: 장소사진은 지도에서 바로 보여야 하므로 public bucket 사용.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('place-photos', 'place-photos', true, 6291456, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists place_photos_storage_insert on storage.objects;
create policy place_photos_storage_insert on storage.objects for insert to authenticated
with check (bucket_id = 'place-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists place_photos_storage_update_admin on storage.objects;
create policy place_photos_storage_update_admin on storage.objects for update to authenticated
using (bucket_id = 'place-photos' and public.is_admin());

drop policy if exists place_photos_storage_delete_admin on storage.objects;
create policy place_photos_storage_delete_admin on storage.objects for delete to authenticated
using (bucket_id = 'place-photos' and public.is_admin());

-- V6: Google Play 외부 회원탈퇴 요청 접수용 테이블
create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  username text not null check (char_length(username) between 4 and 20),
  phone text not null check (char_length(phone) between 10 and 20),
  note text not null default '' check (char_length(note) <= 500),
  status text not null default 'requested' check (status in ('requested','verifying','completed','rejected')),
  requested_at timestamptz not null default now(),
  processed_at timestamptz
);
alter table public.account_deletion_requests enable row level security;
revoke all on public.account_deletion_requests from anon, authenticated;
grant all on public.account_deletion_requests to service_role;
drop policy if exists account_deletion_requests_deny_clients on public.account_deletion_requests;
create policy account_deletion_requests_deny_clients
on public.account_deletion_requests for all to anon, authenticated
using (false) with check (false);
create index if not exists account_deletion_requests_requested_at_idx on public.account_deletion_requests(requested_at desc);
