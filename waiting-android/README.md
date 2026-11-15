# 웨이팅 POS · 안드로이드 매장 운영용 v1.0
- 대상: 도원부산양곱창(dowon), 별밤포차(starbam)
- Android 최소 버전: 6.0 (API 23), 구형 Galaxy Tab E 지원
- 직원용 매장키로 인증하고 대기팀 조회, 다음팀 호출, 5분 후 재호출, 입장/미방문 처리
- 점주 로그인 및 직원용 비밀번호 변경
- 서버: 기존 Supabase Edge Functions (restaurant-waiting-staff, -status, -owner-login)
- 인증키, 점주 비밀번호는 빌드에 포함하지 않으며 앱 저장소에 저장하지 않음
- 별도의 고객용 앱 없음. 고객 접수 QR·모바일웹·메시지 발송은 별도 웹/서버 작업
- 현 백엔드 두 매장 registration_open=false. 실제 고객 접수는 관리자가 서버에서 열어야 함.
- 임시 테스트 배포: Android Debug APK. Play Store 정식 배포용 서명 APK는 아님.
## 자동 빌드
GitHub Actions > Build Waiting POS APK. 브랜치 waiting-android.
결과: artifact waiting-pos-v1-android6-apk > app-debug.apk
