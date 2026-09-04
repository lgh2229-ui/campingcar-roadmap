# Google Play 출시 체크리스트 (V5)

- 패키지명: `kr.co.campingcarroadmap.app`
- 버전: `1.3.0+4`
- targetSdk/compileSdk: API 36으로 패치
- 인앱 회원탈퇴: 구현됨
- 외부 계정삭제 안내 페이지: `delete_account.html` 준비됨 (공개 HTTPS URL에 게시 필요)
- 개인정보처리방침: 초안 준비됨 (운영자/연락처/보관기간 등 실제 정보 입력 후 공개 URL 필요)
- AAB release signing: GitHub Actions용 업로드 키 Secret 방식 추가

## GitHub Secrets
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

업로드 키 파일/비밀번호는 채팅이나 소스 저장소에 올리지 않는다.


## V6 완료 항목
- 외부 회원탈퇴 요청 URL 실제 배포 완료: https://xlpwxkcxpxorrmkgzhft.supabase.co/functions/v1/account-deletion-request
- 탈퇴 요청 테이블은 앱 클라이언트에서 직접 읽기/쓰기 불가(RLS + 권한 차단)
- 15m 이내 중복/겹침 장소 마커 그룹화
- 저장 장소 선택 시 지도 이동 후 상세정보 자동 열기
- 주소 검색 결과 최대 6개 선택 UI
