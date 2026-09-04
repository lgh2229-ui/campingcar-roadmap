# 다음 단계

현재 Flutter 앱은 Supabase 프로젝트에 연결되어 있습니다.

1. Supabase Dashboard에서 해당 프로젝트를 엽니다.
2. SQL Editor → New query를 엽니다.
3. 이 폴더의 `schema.sql` 전체를 붙여넣고 Run을 1회 실행합니다.
4. Authentication → Providers에서 Phone 인증을 사용할 계획이면 Phone provider와 SMS provider를 설정합니다.
5. Storage에서 `place-photos` 버킷/정책은 `schema.sql` 적용 결과를 확인합니다.
6. 이후 앱을 빌드해 회원가입·로그인·장소등록·리뷰·사진 업로드를 테스트합니다.

주의: service_role/secret key는 절대 Flutter 앱에 넣지 않습니다.
