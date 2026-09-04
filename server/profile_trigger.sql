-- V7: Supabase Auth 회원 생성 시 profiles 자동 생성
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  uname text;
begin
  uname := trim(coalesce(new.raw_user_meta_data->>'username', ''));
  if uname = '' then
    return new;
  end if;
  insert into public.profiles(id, username, phone, phone_verified, role)
  values (new.id, uname, regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g'), new.phone_confirmed_at is not null, 'user')
  on conflict (id) do update
    set username = excluded.username,
        phone = case when excluded.phone <> '' then excluded.phone else public.profiles.phone end,
        phone_verified = public.profiles.phone_verified or excluded.phone_verified;
  return new;
end;
$$;

revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;
grant execute on function public.handle_new_auth_user() to supabase_auth_admin;

drop trigger if exists on_auth_user_created_campingcar on auth.users;
create trigger on_auth_user_created_campingcar
after insert on auth.users
for each row execute function public.handle_new_auth_user();
