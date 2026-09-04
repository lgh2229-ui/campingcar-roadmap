# 캠핑카족 로드맵 - Flutter Android V2 서버연결판

V29 HTML 프로토타입 → Flutter V1을 기반으로, Google Play 출시를 위해 Supabase 서버 구조를 연결한 V2입니다.

## 이번 V2에서 추가된 핵심
- Supabase Auth / Database / Storage 연결 구조
- 실제 휴대폰 SMS OTP 회원가입 인증 흐름
- 등록 휴대폰 OTP 기반 아이디 찾기
- 등록 휴대폰 OTP 후 비밀번호 재설정
- 서버 공유 장소 목록
- 서버 공유 저장 장소
- 장소사진 1장 이상 필수 + Supabase Storage 업로드
- 서버 공유 검증리뷰(이용가능/변경/이용불가 + 200자 리뷰)
- 리뷰 작성자 아이디 표시
- `administrator` 관리자 권한을 서버 RLS에서도 재검증
- 일반 회원은 장소 수정 불가, 관리자만 UPDATE/DELETE 가능
- 개인정보 변경 진입 전 현재 비밀번호 재인증
- 차량정보 서버 저장
- Google Play용 개인정보처리방침 초안, 스토어 설명, 데이터 보안 체크 초안
- GitHub Actions AAB 자동 빌드에 Supabase Secrets 연결

## 실행 모드
Supabase 값 없이 실행하면 기존처럼 로컬 개발모드로 작동합니다.

```bash
flutter run
```

Supabase 서버모드:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

## 최초 Supabase 설정
`server/SETUP_KO.md` 순서대로 진행하고, SQL Editor에서 `server/schema.sql`을 실행합니다.

중요: 앱에는 **service_role 키를 넣지 않습니다.** 클라이언트에는 publishable/anon key만 사용합니다.

## 관리자
일반 회원가입에서 `administrator` 아이디는 막혀 있습니다. 관리자 계정은 Supabase Dashboard에서 별도로 만들고 `profiles.role='admin'`을 지정해야 합니다. 장소 수정 권한은 앱 화면뿐 아니라 Postgres RLS가 서버에서 다시 검사합니다.

## Google Play 준비 파일
- `play_store/privacy_policy.html` : 개인정보처리방침 초안
- `play_store/store_listing_ko.txt` : 스토어 설명 초안
- `play_store/data_safety_guide_ko.md` : 데이터 보안 작성 초안

개인정보처리방침은 출시 전에 실제 사업자명/대표자/연락처/보관기간 등을 반드시 채워야 합니다.

## AAB 자동 빌드
GitHub Repository Secrets에 아래 2개를 넣습니다.
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

그 후 Actions → **Build Android AAB** 실행. 빌드 성공 시 `campingcar-roadmap-aab` 아티팩트로 `app-release.aab`를 받을 수 있습니다.

## 아직 계정 작업이 필요한 부분
실제 SMS 발송은 Supabase 프로젝트에서 Phone Provider와 SMS 공급자 설정이 필요합니다. 이 설정에는 사용자의 Supabase 계정 작업이 필요하므로 소스에 비밀키를 하드코딩하지 않았습니다.

## 빌드 검증 상태
현재 ChatGPT 실행 환경에는 Flutter SDK/Dart SDK가 없어 여기서 실제 `flutter analyze`/AAB 컴파일은 실행하지 못했습니다. GitHub Actions는 실제 Flutter 환경에서 analyze 후 AAB를 만들도록 설정돼 있습니다.

## V3 - Supabase 프로젝트 연결됨
이 소스에는 제공된 Supabase Project URL과 publishable key가 기본값으로 연결되어 있습니다.
앱이 실제로 회원/장소/리뷰 데이터를 사용하려면 Supabase SQL Editor에서 `server/schema.sql`을 1회 실행해야 합니다.
publishable key는 모바일 앱에 노출 가능한 클라이언트 키이며, `service_role`/secret key는 앱에 넣으면 안 됩니다.

프로덕션 빌드에서 값을 교체하려면:
```bash
flutter build appbundle \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```


## V6
- Supabase 외부 회원탈퇴 요청 페이지 배포: https://xlpwxkcxpxorrmkgzhft.supabase.co/functions/v1/account-deletion-request
- Google Play 계정 삭제 외부 경로 준비
- 지도 마커 15m 그룹화
- 저장 장소 → 지도 이동 → 상세 자동 열기
- 주소 검색 결과 최대 6개 표시


## V7
V7부터 GitHub Actions에서 Release 서명키 없이도 Debug APK를 생성할 수 있습니다. `Build Android Debug APK` 워크플로는 테스트와 정적 분석을 통과한 뒤 설치용 APK를 artifact로 올립니다. 또한 Supabase Auth 신규 회원 생성 시 profiles 자동생성 트리거가 서버에 적용되어 회원가입 데이터 일관성을 강화했습니다.
