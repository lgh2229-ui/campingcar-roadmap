# V5 변경사항

1. GitHub Actions의 잘못된 `SUPABASE_ANON_KEY` 전달을 `SUPABASE_PUBLISHABLE_KEY`로 수정.
2. Google Play 업로드용 release signing 자동 설정 추가.
3. Android API 36 패치를 유지하고 빌드 단계에서 적용.
4. Google Play 외부 계정삭제 URL용 `play_store/delete_account.html` 추가.
5. Play 출시 체크리스트와 필요한 GitHub Secrets 목록 추가.
6. 버전 `1.3.0+4`로 증가.

주의: 현재 실행 환경에는 Flutter SDK가 없어 실제 AAB 컴파일 검증은 아직 하지 못함.
