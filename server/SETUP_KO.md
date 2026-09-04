# Supabase 연결 순서

1. Supabase에서 새 프로젝트를 만든다.
2. SQL Editor에서 `schema.sql` 전체를 실행한다.
3. Authentication > Providers에서 Phone을 활성화하고 SMS 공급자를 연결한다.
4. Authentication 설정에서 **Confirm email을 끈다.** 이 앱은 사용자에게 이메일을 받지 않고, 내부 로그인용 가상 이메일(`아이디@login.campingcarroadmap.invalid`)을 사용한다.
5. Project Settings > API에서 Project URL과 **publishable/anon key**를 확인한다. service_role 키는 앱에 절대 넣지 않는다.
6. 앱 빌드 시 아래 값을 전달한다.
   - `--dart-define=SUPABASE_URL=...`
   - `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`
7. GitHub Actions를 쓸 경우 Repository Secrets에 `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`를 등록한다.

## administrator 계정
`administrator`는 일반 회원가입에서 예약 아이디로 막아뒀다. 관리자 계정은 Supabase Dashboard에서 직접 만든 뒤 profiles의 role을 `admin`으로 지정한다.

권장 관리자 Auth 이메일:
`administrator@login.campingcarroadmap.invalid`

관리자 profile 예시(실제 auth user UUID로 교체):
```sql
insert into public.profiles(id, username, phone, phone_verified, role)
values ('관리자-auth-uuid', 'administrator', '01012345678', true, 'admin')
on conflict (id) do update set username='administrator', role='admin', phone_verified=true;
```

관리자 권한은 앱 화면의 아이디 비교만으로 결정하지 않는다. `places UPDATE/DELETE` RLS가 `role='admin'` + `username='administrator'`를 서버에서 다시 검사한다.

## SMS
Supabase Phone Auth는 실제 SMS 공급자 설정이 되어 있어야 동작한다. 공급자 비용은 별도 발생할 수 있다. 테스트 단계에서는 Supabase 대시보드의 테스트 OTP 기능을 사용해도 된다.

## 사진
`schema.sql`이 `place-photos` public bucket과 업로드 정책을 만든다. 앱은 사진 1~6장을 선택하며, 각 파일은 6MB 이하가 권장/허용된다.
