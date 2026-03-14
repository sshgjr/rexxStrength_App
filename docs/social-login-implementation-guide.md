# 소셜 로그인 구현 가이드

## 개요
현재 로그인 화면에 Apple / Google / 카카오 소셜 로그인 버튼이 UI로만 배치되어 있음.
이 문서는 실제 기능 구현 시 필요한 작업을 정리한다.

## Flutter 패키지
- Apple: `sign_in_with_apple` (^6.0.0)
- Google: `google_sign_in` (^6.2.0)
- 카카오: `kakao_flutter_sdk_user` (^1.9.0)

## 백엔드 엔드포인트 설계

### POST /auth/social
```json
{
  "provider": "apple" | "google" | "kakao",
  "id_token": "...",
  "access_token": "..."
}
```

### 처리 흐름
1. 클라이언트에서 소셜 SDK로 인증 → id_token 획득
2. id_token을 백엔드로 전송
3. 백엔드에서 provider별 토큰 검증:
   - Apple: `python-jose`로 Apple 공개키 기반 JWT 검증
   - Google: `google-auth` 라이브러리로 id_token 검증
   - 카카오: 카카오 API (`/v2/user/me`)로 access_token 검증
4. 이메일 추출 → 기존 사용자면 로그인, 없으면 자동 회원가입
5. JWT 토큰 발급하여 반환

### User 모델 변경
```python
class User(Base):
    # 기존 필드...
    social_provider = Column(String(20), nullable=True)  # "apple", "google", "kakao"
    social_id = Column(String(255), nullable=True, unique=True)
```

### 백엔드 패키지 추가
```
google-auth>=2.0.0
httpx>=0.27.0
```

## 플랫폼별 설정

### Apple Sign In
- Apple Developer에서 Sign In with Apple capability 활성화
- Service ID 생성 (redirect URL 등록)
- iOS: Xcode에서 Sign In with Apple capability 추가
- Android: 웹 기반 Apple Sign In 사용

### Google Sign In
- Google Cloud Console에서 OAuth 2.0 클라이언트 ID 생성
- iOS: `GoogleService-Info.plist` 추가
- Android: `google-services.json` 추가, SHA-1 등록

### 카카오 로그인
- Kakao Developers에서 앱 등록
- iOS: URL Scheme 설정 (`kakao{APP_KEY}`)
- Android: 키 해시 등록
- `pubspec.yaml`에 카카오 SDK 추가
