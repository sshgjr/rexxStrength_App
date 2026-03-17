모든 테스트를 실행하여 코드 변경 사항이 정상 동작하는지 확인합니다.

## 실행할 테스트

### 1. 백엔드 (FastAPI) 테스트
```bash
cd rexx_server && ./venv/bin/python -m pytest tests/ -v
```

### 2. Flutter 테스트
```bash
cd rexx_app && flutter test
```

### 3. Flutter 정적 분석
```bash
cd rexx_app && flutter analyze
```

## 규칙
- 모든 테스트를 순서대로 실행하세요.
- 테스트가 실패하면 실패한 테스트 목록과 원인을 보고하세요.
- 모든 테스트가 통과하면 "모든 테스트 통과" 메시지를 출력하세요.
- 정적 분석 경고가 있으면 목록을 보고하세요.
