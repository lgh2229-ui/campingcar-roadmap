# V4 변경사항

- Supabase `delete-account` Edge Function 연동 및 인앱 회원탈퇴 추가
- 회원탈퇴 전 현재 비밀번호 재확인 + 최종 확인
- 탈퇴 시 사용자 소유 장소사진 Storage 정리 후 Auth 사용자 삭제
- 관리자 장소 수정 범위를 서비스/가격/운영시간/예약/높이/연락처/주소/주의사항까지 확대
- 차량 높이와 장소 진입 제한 높이를 비교해 진입가능/주의/불가 표시
- 장소사진 선택 코드 중복 호출 버그 수정
- Android 생성 후 compileSdk/targetSdk API 36 패치 추가

## 아직 외부 설정이 필요한 항목
- 실제 SMS 발송은 Supabase Auth에 SMS 제공자 설정이 필요합니다.
- `administrator` Auth 계정 생성에는 실제 관리자 비밀번호/전화번호가 필요하므로 자동 생성하지 않았습니다.
- 이 실행환경에는 Flutter SDK가 없어 AAB 실컴파일은 아직 하지 못했습니다.
