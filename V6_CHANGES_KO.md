# V6 변경사항

버전: 1.4.0+5

- Supabase에 `account_deletion_requests` 테이블 추가 및 클라이언트 직접 접근 차단
- 실제 외부 회원탈퇴 요청 Edge Function `account-deletion-request` 배포
- Google Play 외부 계정삭제 요청 경로 준비
- 15m 이내 장소를 하나의 그룹 마커로 묶어 중복 마커 개선
- 그룹 마커 탭 시 해당 위치의 장소 목록 선택 가능
- 저장한 장소 탭 시 지도 이동 후 장소 상세정보 자동 표시
- 주소/지역 검색 결과를 최대 6개까지 보여주고 선택 가능
- 기존 API 36 / Release Signing / Supabase / 회원탈퇴 기능 유지

실제 SMS 발송은 Supabase Auth의 SMS 공급자 설정이 별도로 필요합니다.
실제 Play Store 업로드용 AAB는 Flutter SDK와 업로드 서명키가 있는 빌드 환경에서 검증해야 합니다.
