# V7 변경사항

- Supabase Auth 신규 회원 생성 시 `profiles` 행을 서버 트리거로 자동 생성.
- 트리거 함수는 `anon`/`authenticated` 직접 실행을 차단하고 Auth 관리자 역할만 실행 가능.
- GitHub Actions에 **서명키 없이 설치 가능한 Debug APK** 빌드 워크플로 추가.
- Debug APK 빌드 전 `flutter test` + `flutter analyze` 실행.
- Release AAB 워크플로에도 `flutter test` 단계 추가.
- Place/AppUser 핵심 모델 회귀 테스트 추가.
- 앱 버전 `1.5.0+6`.

## 실제 빌드
이 소스 자체는 현재 실행환경에 Flutter SDK가 없어 로컬 컴파일하지 못했다. GitHub에 올린 뒤 Actions의 `Build Android Debug APK`를 실행하면 서명키 없이 테스트용 APK를 만들 수 있다.
