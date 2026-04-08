# 2-레이어 피드백 시스템 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 운동 자세 평가 결과를 부상 위험(L1)/스타일 허용(L2)으로 분류하고, 사용자 등급별 차등 피드백을 제공하는 시스템 구현

**Architecture:** 로컬 Rule Engine 결과를 JSON 설정 파일 기반 LayerClassifier로 분류 → 사용자 등급(서버 DB + 로컬 캐시)과 함께 서버 Gemini API에 전달 → 조건부 프롬프트로 3종 피드백(feedback/keypoint/cause) 생성. 상급자+L2만일 때는 서버 호출 스킵.

**Tech Stack:** Flutter/Dart (프론트), FastAPI/Python (백엔드), PostgreSQL (Railway), Gemini 2.5 Flash Lite, SharedPreferences

**Spec:** `docs/superpowers/specs/2026-03-31-two-layer-feedback-system-design.md`

---

## 파일 구조

### 신규 파일
| 파일 | 역할 |
|------|------|
| `rexx_app/assets/config/layer_config.json` | 운동별 레이어 분류 설정 |
| `rexx_app/lib/features/pose_evaluation/engine/layer_classifier.dart` | 레이어 분류 모듈 |
| `rexx_app/lib/services/level_service.dart` | 사용자 등급 CRUD + 자동 제안 로직 |
| `rexx_app/lib/features/pose_evaluation/widgets/level_suggestion_sheet.dart` | 등급 변경 제안 바텀시트 |
| `rexx_app/test/features/pose_evaluation/engine/layer_classifier_test.dart` | LayerClassifier 유닛 테스트 |
| `rexx_app/test/services/level_service_test.dart` | LevelService 유닛 테스트 |
| `rexx_server/tests/test_gemini_service.py` | Gemini 서비스 유닛 테스트 |

### 수정 파일
| 파일 | 변경 |
|------|------|
| `rexx_app/lib/features/pose_evaluation/models/evaluation_result.dart` | LayerClassification 필드 추가 |
| `rexx_app/lib/features/pose_evaluation/engine/pose_analyzer.dart` | LayerClassifier 호출 추가 |
| `rexx_app/lib/services/pose_feedback_service.dart` | 레이어 데이터+등급 전송 |
| `rexx_app/lib/features/pose_evaluation/widgets/feedback_card.dart` | 3종 포맷 + 조건부 스타일 |
| `rexx_app/lib/features/pose_evaluation/screens/video_upload_screen.dart` | 등급 로드 + 출력 결정 로직 |
| `rexx_app/lib/features/pose_evaluation/screens/pose_result_screen.dart` | 등급 제안 다이얼로그 트리거 |
| `rexx_app/lib/pages/home_screen.dart` | 설정에 등급 선택 진입점 |
| `rexx_app/pubspec.yaml` | assets 경로 추가 |
| `rexx_server/auth.py` | User 모델에 level 컬럼 |
| `rexx_server/main.py` | PUT /me/level 엔드포인트, _user_response에 level 추가 |
| `rexx_server/schemas/pose_schemas.py` | LayerIssue, 신규 필드 |
| `rexx_server/services/gemini_service.py` | 조건부 프롬프트, 3종 출력 |
| `rexx_server/routers/pose_feedback.py` | 레이어 데이터 수신, 스킵 로직 |

---

### Task 1: 레이어 설정 JSON 파일 생성

**Files:**
- Create: `rexx_app/assets/config/layer_config.json`
- Modify: `rexx_app/pubspec.yaml`

- [ ] **Step 1: layer_config.json 생성**

```json
{
  "version": 1,
  "exercises": {
    "squat": {
      "layer1": [
        { "criterion": "척추 각도", "reason": "요추 과굴곡 → 허리 부상 위험" },
        { "criterion": "무릎-발끝 정렬", "reason": "무릎 cave-in → ACL 부상 위험" }
      ],
      "layer2": [
        { "criterion": "무릎 각도", "reason": "스쿼트 깊이는 스타일 차이" },
        { "criterion": "힙 힌지", "reason": "하이바/로우바 스타일" },
        { "criterion": "좌우 대칭", "reason": "경미한 비대칭은 자연스러운 개인차" }
      ]
    },
    "deadlift": {
      "layer1": [
        { "criterion": "등 각도", "reason": "요추 과굴곡(둥근 등) → 디스크 부상 위험" },
        { "criterion": "좌우 대칭", "reason": "고중량 비대칭 → 척추 측방 부하 부상" }
      ],
      "layer2": [
        { "criterion": "힙 힌지 패턴", "reason": "컨벤셔널/스모 등 스타일 차이" },
        { "criterion": "락아웃", "reason": "락아웃 정도는 경기/훈련 목적에 따라 다름" },
        { "criterion": "무릎 각도", "reason": "시작 자세 무릎 각도는 스타일 차이" }
      ]
    },
    "bench_press": {
      "layer1": [
        { "criterion": "팔꿈치 벌어짐", "reason": "과도한 flare → 어깨 충돌증후군 위험" },
        { "criterion": "팔꿈치 각도", "reason": "바텀 과도한 스트레치 → 어깨/흉근 파열 위험" }
      ],
      "layer2": [
        { "criterion": "바 경로", "reason": "바 경로는 체형/그립에 따라 다름" },
        { "criterion": "락아웃", "reason": "완전 락아웃 여부는 훈련 목적 차이" },
        { "criterion": "좌우 대칭", "reason": "경미한 좌우 차이는 자연스러운 범위" }
      ]
    },
    "wrist_curl": {
      "layer1": [
        { "criterion": "팔꿈치 고정도", "reason": "팔꿈치 불안정 → 관절 과부하 부상 위험" }
      ],
      "layer2": [
        { "criterion": "손목 가동범위", "reason": "ROM은 개인 유연성 차이" },
        { "criterion": "동작 일관성", "reason": "숙련도에 따른 자연스러운 차이" },
        { "criterion": "최대 수축", "reason": "훈련 목적에 따라 의도적 조절 가능" },
        { "criterion": "좌우 대칭", "reason": "경미한 차이는 자연스러움" }
      ]
    }
  }
}
```

- [ ] **Step 2: pubspec.yaml에 assets 경로 추가**

`rexx_app/pubspec.yaml`의 `assets:` 섹션에 추가:

```yaml
  assets:
    - assets/config/
```

기존 assets가 이미 있으면 해당 리스트에 `- assets/config/` 한 줄 추가.

- [ ] **Step 3: 커밋**

```bash
git add rexx_app/assets/config/layer_config.json rexx_app/pubspec.yaml
git commit -m "feat: 운동별 레이어 분류 설정 JSON 파일 추가"
```

---

### Task 2: LayerClassifier 모델 및 분류기 구현 (TDD)

**Files:**
- Create: `rexx_app/lib/features/pose_evaluation/engine/layer_classifier.dart`
- Create: `rexx_app/test/features/pose_evaluation/engine/layer_classifier_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`rexx_app/test/features/pose_evaluation/engine/layer_classifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/engine/layer_classifier.dart';
import 'package:rexx_app/features/pose_evaluation/models/evaluation_result.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';

void main() {
  late LayerClassifier classifier;

  setUp(() {
    // 테스트용 인라인 설정 (JSON 파일 로드 대신)
    classifier = LayerClassifier.fromMap({
      'squat': {
        'layer1': [
          {'criterion': '척추 각도', 'reason': '요추 과굴곡 → 허리 부상 위험'},
          {'criterion': '무릎-발끝 정렬', 'reason': '무릎 cave-in → ACL 부상 위험'},
        ],
        'layer2': [
          {'criterion': '무릎 각도', 'reason': '스쿼트 깊이는 스타일 차이'},
          {'criterion': '힙 힌지', 'reason': '하이바/로우바 스타일'},
          {'criterion': '좌우 대칭', 'reason': '경미한 비대칭은 자연스러운 개인차'},
        ],
      },
    });
  });

  group('LayerClassifier.classify', () {
    test('Bad 등급 L1 기준은 layer1Issues에 분류', () {
      final criteria = [
        const CriterionResult(name: '척추 각도', description: '척추 각도', score: 30, weight: 0.15, grade: CriterionGrade.bad),
        const CriterionResult(name: '무릎 각도', description: '무릎 각도 (바텀)', score: 90, weight: 0.30, grade: CriterionGrade.good),
      ];

      final result = classifier.classify(criteria, ExerciseType.squat);

      expect(result.layer1Issues.length, 1);
      expect(result.layer1Issues.first.criterion.name, '척추 각도');
      expect(result.layer2Issues, isEmpty);
    });

    test('Warning 등급 L2 기준은 layer2Issues에 분류', () {
      final criteria = [
        const CriterionResult(name: '척추 각도', description: '척추 각도', score: 90, weight: 0.15, grade: CriterionGrade.good),
        const CriterionResult(name: '무릎 각도', description: '무릎 각도 (바텀)', score: 60, weight: 0.30, grade: CriterionGrade.warning),
      ];

      final result = classifier.classify(criteria, ExerciseType.squat);

      expect(result.layer1Issues, isEmpty);
      expect(result.layer2Issues.length, 1);
      expect(result.layer2Issues.first.criterion.name, '무릎 각도');
    });

    test('Good 등급 기준은 이슈로 분류되지 않음', () {
      final criteria = [
        const CriterionResult(name: '척추 각도', description: '척추 각도', score: 90, weight: 0.15, grade: CriterionGrade.good),
        const CriterionResult(name: '무릎 각도', description: '무릎 각도 (바텀)', score: 95, weight: 0.30, grade: CriterionGrade.good),
      ];

      final result = classifier.classify(criteria, ExerciseType.squat);

      expect(result.hasNoIssues, isTrue);
    });

    test('설정에 없는 기준은 L2로 기본 분류', () {
      final criteria = [
        const CriterionResult(name: '알 수 없는 기준', description: '알 수 없음', score: 40, weight: 0.10, grade: CriterionGrade.bad),
      ];

      final result = classifier.classify(criteria, ExerciseType.squat);

      expect(result.layer2Issues.length, 1);
      expect(result.layer1Issues, isEmpty);
    });

    test('hasLayer1, hasLayer2Only 플래그 정확성', () {
      // L1만 있는 경우
      final l1Only = classifier.classify([
        const CriterionResult(name: '척추 각도', description: '척추 각도', score: 30, weight: 0.15, grade: CriterionGrade.bad),
      ], ExerciseType.squat);
      expect(l1Only.hasLayer1, isTrue);
      expect(l1Only.hasLayer2Only, isFalse);

      // L2만 있는 경우
      final l2Only = classifier.classify([
        const CriterionResult(name: '힙 힌지', description: '힙 힌지 각도', score: 60, weight: 0.20, grade: CriterionGrade.warning),
      ], ExerciseType.squat);
      expect(l2Only.hasLayer1, isFalse);
      expect(l2Only.hasLayer2Only, isTrue);
    });
  });

  group('FeedbackDecision', () {
    test('L1 감지 시 등급 무관 출력', () {
      final classification = LayerClassification(
        layer1Issues: [LayerIssue(criterion: const CriterionResult(name: '척추 각도', description: '척추 각도', score: 30, weight: 0.15, grade: CriterionGrade.bad), reason: '부상 위험')],
        layer2Issues: [],
      );

      expect(classification.shouldRequestFeedback(UserLevel.beginner), isTrue);
      expect(classification.shouldRequestFeedback(UserLevel.intermediate), isTrue);
      expect(classification.shouldRequestFeedback(UserLevel.advanced), isTrue);
    });

    test('L2만 감지 시 상급자는 피드백 스킵', () {
      final classification = LayerClassification(
        layer1Issues: [],
        layer2Issues: [LayerIssue(criterion: const CriterionResult(name: '힙 힌지', description: '힙 힌지 각도', score: 60, weight: 0.20, grade: CriterionGrade.warning), reason: '스타일')],
      );

      expect(classification.shouldRequestFeedback(UserLevel.beginner), isTrue);
      expect(classification.shouldRequestFeedback(UserLevel.intermediate), isTrue);
      expect(classification.shouldRequestFeedback(UserLevel.advanced), isFalse);
    });

    test('이슈 없으면 모든 등급 피드백 스킵', () {
      final classification = LayerClassification(layer1Issues: [], layer2Issues: []);

      expect(classification.shouldRequestFeedback(UserLevel.beginner), isFalse);
      expect(classification.shouldRequestFeedback(UserLevel.intermediate), isFalse);
      expect(classification.shouldRequestFeedback(UserLevel.advanced), isFalse);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd rexx_app && flutter test test/features/pose_evaluation/engine/layer_classifier_test.dart
```

Expected: 컴파일 에러 (layer_classifier.dart 없음)

- [ ] **Step 3: LayerClassifier 구현**

`rexx_app/lib/features/pose_evaluation/engine/layer_classifier.dart`:

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/evaluation_result.dart';
import '../models/exercise_phase.dart';

/// 사용자 등급
enum UserLevel {
  beginner,
  intermediate,
  advanced;

  String get apiName => name;

  String get displayName {
    switch (this) {
      case UserLevel.beginner:
        return '초급';
      case UserLevel.intermediate:
        return '중급';
      case UserLevel.advanced:
        return '상급';
    }
  }

  static UserLevel fromString(String value) {
    return UserLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserLevel.beginner,
    );
  }
}

/// 레이어 분류된 이슈 항목
class LayerIssue {
  final CriterionResult criterion;
  final String reason;

  const LayerIssue({required this.criterion, required this.reason});

  Map<String, dynamic> toJson() => {
        'criterion': criterion.name,
        'score': criterion.score,
        'grade': criterion.grade.name,
        'reason': reason,
      };
}

/// 레이어 분류 결과
class LayerClassification {
  final List<LayerIssue> layer1Issues;
  final List<LayerIssue> layer2Issues;

  const LayerClassification({
    required this.layer1Issues,
    required this.layer2Issues,
  });

  bool get hasLayer1 => layer1Issues.isNotEmpty;
  bool get hasLayer2Only => !hasLayer1 && layer2Issues.isNotEmpty;
  bool get hasNoIssues => layer1Issues.isEmpty && layer2Issues.isEmpty;

  /// 서버에 피드백을 요청해야 하는지 결정
  bool shouldRequestFeedback(UserLevel level) {
    if (hasNoIssues) return false;
    if (hasLayer1) return true;
    // L2만 감지된 경우
    if (level == UserLevel.advanced) return false;
    return true;
  }
}

/// 레이어 분류기 — layer_config.json 기반
class LayerClassifier {
  final Map<String, _ExerciseLayerConfig> _config;

  LayerClassifier._(this._config);

  /// JSON 에셋에서 로드
  static Future<LayerClassifier> load() async {
    final jsonStr = await rootBundle.loadString('assets/config/layer_config.json');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return _parseConfig(data);
  }

  /// 테스트용 — Map에서 직접 생성
  factory LayerClassifier.fromMap(Map<String, dynamic> exercises) {
    return _parseConfig({'version': 1, 'exercises': exercises});
  }

  static LayerClassifier _parseConfig(Map<String, dynamic> data) {
    final exercises = data['exercises'] as Map<String, dynamic>;
    final config = <String, _ExerciseLayerConfig>{};

    for (final entry in exercises.entries) {
      final exerciseData = entry.value as Map<String, dynamic>;
      final l1 = (exerciseData['layer1'] as List<dynamic>)
          .map((e) => _LayerEntry(
                criterion: e['criterion'] as String,
                reason: e['reason'] as String,
              ))
          .toList();
      final l2 = (exerciseData['layer2'] as List<dynamic>)
          .map((e) => _LayerEntry(
                criterion: e['criterion'] as String,
                reason: e['reason'] as String,
              ))
          .toList();
      config[entry.key] = _ExerciseLayerConfig(layer1: l1, layer2: l2);
    }

    return LayerClassifier._(config);
  }

  /// 기준 결과를 레이어별로 분류
  LayerClassification classify(List<CriterionResult> criteria, ExerciseType exerciseType) {
    final exerciseConfig = _config[exerciseType.apiName];
    final l1Issues = <LayerIssue>[];
    final l2Issues = <LayerIssue>[];

    for (final c in criteria) {
      if (c.grade == CriterionGrade.good) continue;

      final l1Entry = exerciseConfig?.layer1.where((e) => e.criterion == c.name).firstOrNull;

      if (l1Entry != null) {
        l1Issues.add(LayerIssue(criterion: c, reason: l1Entry.reason));
      } else {
        final l2Entry = exerciseConfig?.layer2.where((e) => e.criterion == c.name).firstOrNull;
        final reason = l2Entry?.reason ?? '스타일 관련 항목';
        l2Issues.add(LayerIssue(criterion: c, reason: reason));
      }
    }

    return LayerClassification(layer1Issues: l1Issues, layer2Issues: l2Issues);
  }
}

class _ExerciseLayerConfig {
  final List<_LayerEntry> layer1;
  final List<_LayerEntry> layer2;
  const _ExerciseLayerConfig({required this.layer1, required this.layer2});
}

class _LayerEntry {
  final String criterion;
  final String reason;
  const _LayerEntry({required this.criterion, required this.reason});
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
cd rexx_app && flutter test test/features/pose_evaluation/engine/layer_classifier_test.dart
```

Expected: All tests PASS

- [ ] **Step 5: 커밋**

```bash
git add rexx_app/lib/features/pose_evaluation/engine/layer_classifier.dart rexx_app/test/features/pose_evaluation/engine/layer_classifier_test.dart
git commit -m "feat: LayerClassifier 레이어 분류 모듈 구현 (TDD)"
```

---

### Task 3: 서버 — User 모델에 level 필드 추가 + API 엔드포인트

**Files:**
- Modify: `rexx_server/auth.py:29-39`
- Modify: `rexx_server/main.py:47-87,148-153`
- Modify: `rexx_server/tests/conftest.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`rexx_server/tests/test_user_level.py`:

```python
def test_default_level_is_beginner(client, registered_user):
    """신규 사용자의 기본 등급은 beginner."""
    token = registered_user["token"]
    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    assert res.json()["user"]["level"] == "beginner"


def test_update_level(client, registered_user):
    """등급 변경 API 정상 동작."""
    token = registered_user["token"]
    headers = {"Authorization": f"Bearer {token}"}

    res = client.put("/me/level", json={"level": "intermediate"}, headers=headers)
    assert res.status_code == 200
    assert res.json()["level"] == "intermediate"

    # 변경 확인
    me = client.get("/me", headers=headers)
    assert me.json()["user"]["level"] == "intermediate"


def test_update_level_invalid(client, registered_user):
    """잘못된 등급값은 422 반환."""
    token = registered_user["token"]
    headers = {"Authorization": f"Bearer {token}"}

    res = client.put("/me/level", json={"level": "grandmaster"}, headers=headers)
    assert res.status_code == 422


def test_update_level_requires_auth(client):
    """비인증 요청은 401 반환."""
    res = client.put("/me/level", json={"level": "intermediate"})
    assert res.status_code == 401
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd rexx_server && python -m pytest tests/test_user_level.py -v
```

Expected: FAIL (level 필드 없음, /me/level 엔드포인트 없음)

- [ ] **Step 3: User 모델에 level 컬럼 추가**

`rexx_server/auth.py`의 `User` 클래스에 추가 (line 39, `interests` 아래):

```python
    level = Column(String(20), nullable=False, server_default="beginner")  # beginner, intermediate, advanced
```

- [ ] **Step 4: main.py에 등급 변경 API + 응답에 level 포함**

`rexx_server/main.py`에 추가:

스키마 추가 (LoginRequest 아래):

```python
from enum import Enum

class UserLevelEnum(str, Enum):
    beginner = "beginner"
    intermediate = "intermediate"
    advanced = "advanced"

class UpdateLevelRequest(BaseModel):
    level: UserLevelEnum
```

`_user_response` 함수에 level 추가:

```python
def _user_response(user: User) -> dict:
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "height": user.height,
        "weight": user.weight,
        "is_body_public": user.is_body_public,
        "interests": json.loads(user.interests) if user.interests else None,
        "level": user.level,
    }
```

`UserResponse`에 level 추가:

```python
class UserResponse(BaseModel):
    id: int
    username: str
    email: EmailStr
    height: Optional[float] = None
    weight: Optional[float] = None
    is_body_public: bool = False
    interests: Optional[List[str]] = None
    level: str = "beginner"
```

등급 변경 엔드포인트 추가 (`get_me` 아래):

```python
@app.put("/me/level")
def update_level(
    data: UpdateLevelRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.level = data.level.value
    db.commit()
    db.refresh(current_user)
    return {"success": True, "level": current_user.level}
```

- [ ] **Step 5: 테스트 실행 — 통과 확인**

```bash
cd rexx_server && python -m pytest tests/test_user_level.py -v
```

Expected: All tests PASS

- [ ] **Step 6: 기존 테스트 전체 통과 확인**

```bash
cd rexx_server && python -m pytest -v
```

Expected: All tests PASS

- [ ] **Step 7: 커밋**

```bash
git add rexx_server/auth.py rexx_server/main.py rexx_server/tests/test_user_level.py
git commit -m "feat: User 모델에 level 필드 추가 + PUT /me/level API"
```

---

### Task 4: 서버 — Gemini 서비스 조건부 프롬프트 + 3종 출력

**Files:**
- Modify: `rexx_server/services/gemini_service.py`
- Modify: `rexx_server/schemas/pose_schemas.py`
- Modify: `rexx_server/routers/pose_feedback.py`
- Create: `rexx_server/tests/test_gemini_service.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`rexx_server/tests/test_gemini_service.py`:

```python
import json
from unittest.mock import patch
from services.gemini_service import generate_feedback, _fallback_feedback


def test_fallback_returns_three_fields():
    """폴백 피드백이 feedback/keypoint/cause 3종 필드를 포함."""
    result = _fallback_feedback("squat", 60, ["척추 각도: 개선 필요 (30점)"])
    data = json.loads(result)
    assert "feedback" in data
    assert "keypoint" in data
    assert "cause" in data


def test_fallback_empty_issues():
    """이슈 없을 때 폴백 피드백."""
    result = _fallback_feedback("squat", 90, [])
    data = json.loads(result)
    assert "feedback" in data
    assert "keypoint" in data


def test_generate_feedback_with_layers():
    """레이어 정보가 포함된 호출이 에러 없이 동작 (API 키 없으면 폴백)."""
    result = generate_feedback(
        exercise_type="squat",
        total_score=60,
        criteria_scores=[{"name": "척추 각도", "score": 30, "grade": "bad"}],
        detected_issues=["척추 각도: 개선 필요"],
        user_level="beginner",
        layer1_issues=[{"criterion": "척추 각도", "score": 30, "grade": "bad", "reason": "요추 과굴곡"}],
        layer2_issues=[],
    )
    data = json.loads(result)
    assert "feedback" in data
    assert "keypoint" in data
    assert "cause" in data
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd rexx_server && python -m pytest tests/test_gemini_service.py -v
```

Expected: FAIL (시그니처 변경 필요)

- [ ] **Step 3: 스키마 변경**

`rexx_server/schemas/pose_schemas.py`를 전체 교체:

```python
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class CriterionScore(BaseModel):
    name: str
    description: str
    score: float
    weight: float
    grade: str


class LayerIssue(BaseModel):
    criterion: str
    score: float
    grade: str
    reason: str


class PoseFeedbackRequest(BaseModel):
    exercise_type: str
    total_score: int
    criteria_scores: List[CriterionScore]
    detected_issues: List[str]
    # 신규 필드 (하위 호환: 기본값 제공)
    user_level: str = "beginner"
    layer1_issues: List[LayerIssue] = []
    layer2_issues: List[LayerIssue] = []


class PoseFeedbackResponse(BaseModel):
    success: bool
    feedback: str
    session_id: Optional[int] = None


class PoseHistoryItem(BaseModel):
    id: int
    exercise_type: str
    total_score: int
    feedback_text: Optional[str]
    created_at: datetime


class PoseHistoryResponse(BaseModel):
    success: bool
    history: List[PoseHistoryItem]
```

- [ ] **Step 4: Gemini 서비스 변경**

`rexx_server/services/gemini_service.py`를 전체 교체:

```python
import os
import json
import traceback
import google.generativeai as genai


def _build_system_prompt(user_level: str, has_layer1: bool) -> str:
    level_instructions = {
        "beginner": "레이어 2 항목: 원인과 구체적인 수정 방법을 안내해라.",
        "intermediate": "레이어 2 항목: '~해보시는 것도 좋습니다' 식의 부드러운 참고 안내만 해라.",
        "advanced": "레이어 2 항목: 언급하지 마라.",
    }

    return f"""너는 운동 코치다.
입력된 분석 결과를 바탕으로 아래 규칙에 따라 한국어 피드백을 생성해라.

규칙:
- 레이어 1 항목(부상 위험): 등급 무관, 반드시 경고. 부상 위험을 명확히 전달
- {level_instructions.get(user_level, level_instructions["beginner"])}
- 운동 초보자도 이해할 수 있게 써라
- 가장 중요한 문제 1~2개만 말해라
- 비난하지 말고 코칭 톤으로 써라
- 추상적인 말 대신 바로 실행 가능한 행동을 써라

출력 형식(JSON):
{{
  "feedback": "상세 설명 (2~3문장)",
  "keypoint": "핵심 한 문장 (8~16자)",
  "cause": "자세 문제 원인 분석 (1~2문장)"
}}"""


def generate_feedback(
    exercise_type: str,
    total_score: int,
    criteria_scores: list,
    detected_issues: list,
    user_level: str = "beginner",
    layer1_issues: list | None = None,
    layer2_issues: list | None = None,
) -> str:
    """Gemini 2.5 Flash Lite를 사용하여 운동 자세 피드백 생성"""

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("[GeminiService] GEMINI_API_KEY가 설정되지 않음, 기본 피드백 반환")
        return _fallback_feedback(exercise_type, total_score, detected_issues)

    exercise_names = {
        "squat": "스쿼트",
        "bench_press": "벤치프레스",
        "deadlift": "데드리프트",
        "wrist_curl": "리스트컬",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    criteria_text = "\n".join(
        f"- {c['name']}: {c['score']:.0f}점 ({c['grade']})"
        for c in criteria_scores
    )

    # 레이어별 이슈 텍스트 구성
    l1_text = "없음"
    l2_text = "없음"
    has_layer1 = False

    if layer1_issues:
        has_layer1 = True
        l1_text = "\n".join(
            f"- {i['criterion']}: {i['score']:.0f}점 ({i['grade']}) — {i['reason']}"
            for i in layer1_issues
        )

    if layer2_issues:
        l2_text = "\n".join(
            f"- {i['criterion']}: {i['score']:.0f}점 ({i['grade']}) — {i['reason']}"
            for i in layer2_issues
        )

    user_message = f"""운동: {exercise_name}
총점: {total_score}/100
사용자 등급: {user_level}

기준별 점수:
{criteria_text}

[레이어 1 — 부상 위험 항목]
{l1_text}

[레이어 2 — 스타일 허용 항목]
{l2_text}"""

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            system_instruction=_build_system_prompt(user_level, has_layer1),
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                max_output_tokens=400,
                temperature=0.7,
            ),
        )

        response = model.generate_content(user_message)
        result_text = response.text.strip()

        # JSON 유효성 검증
        json.loads(result_text)
        return result_text

    except Exception as e:
        print(f"[GeminiService] Gemini API 호출 실패: {e}")
        traceback.print_exc()
        return _fallback_feedback(exercise_type, total_score, detected_issues)


def _fallback_feedback(exercise_type: str, total_score: int, detected_issues: list) -> str:
    """API 실패 시 기본 피드백 (3종 JSON 형식)"""
    exercise_names = {
        "squat": "스쿼트",
        "bench_press": "벤치프레스",
        "deadlift": "데드리프트",
        "wrist_curl": "리스트컬",
    }
    exercise_name = exercise_names.get(exercise_type, exercise_type)

    if detected_issues:
        feedback = f"{exercise_name} 분석 결과, {detected_issues[0]} 부분에서 개선이 필요합니다."
        keypoint = "자세 교정이 필요해요"
        cause = f"{detected_issues[0]}에서 문제가 감지되었습니다."
    else:
        feedback = f"{exercise_name} 전반적으로 양호한 자세입니다."
        keypoint = "좋은 자세입니다"
        cause = "특별한 문제가 감지되지 않았습니다."

    fallback = {
        "feedback": feedback,
        "keypoint": keypoint,
        "cause": cause,
    }
    return json.dumps(fallback, ensure_ascii=False)
```

- [ ] **Step 5: 라우터 변경 — 레이어 데이터 전달 + 스킵 로직**

`rexx_server/routers/pose_feedback.py`의 `create_feedback` 함수를 교체:

```python
@router.post("/feedback", response_model=PoseFeedbackResponse)
@limiter.limit("5/minute")
def create_feedback(
    request: Request,
    data: PoseFeedbackRequest,
    current_user: User | None = Depends(get_optional_current_user),
    db: Session = Depends(get_db),
):
    # 상급자 + L2만 또는 이슈 없음 → 스킵
    has_l1 = len(data.layer1_issues) > 0
    has_l2 = len(data.layer2_issues) > 0
    no_issues = not has_l1 and not has_l2

    if no_issues or (data.user_level == "advanced" and not has_l1 and has_l2):
        feedback_text = json.dumps(
            {"feedback": "", "keypoint": "", "cause": ""},
            ensure_ascii=False,
        )
    else:
        feedback_text = generate_feedback(
            exercise_type=data.exercise_type,
            total_score=data.total_score,
            criteria_scores=[c.model_dump() for c in data.criteria_scores],
            detected_issues=data.detected_issues,
            user_level=data.user_level,
            layer1_issues=[i.model_dump() for i in data.layer1_issues],
            layer2_issues=[i.model_dump() for i in data.layer2_issues],
        )

    session_id = None

    if current_user is not None:
        evaluation = PoseEvaluation(
            user_id=current_user.id,
            exercise_type=data.exercise_type,
            total_score=data.total_score,
            criteria_scores_json=json.dumps(
                [c.model_dump() for c in data.criteria_scores], ensure_ascii=False
            ),
            detected_issues_json=json.dumps(data.detected_issues, ensure_ascii=False),
            feedback_text=feedback_text,
        )
        db.add(evaluation)
        db.commit()
        db.refresh(evaluation)
        session_id = evaluation.id

    return {
        "success": True,
        "feedback": feedback_text,
        "session_id": session_id,
    }
```

- [ ] **Step 6: 테스트 실행 — 통과 확인**

```bash
cd rexx_server && python -m pytest tests/test_gemini_service.py tests/test_pose_feedback.py -v
```

Expected: All tests PASS

- [ ] **Step 7: 커밋**

```bash
git add rexx_server/services/gemini_service.py rexx_server/schemas/pose_schemas.py rexx_server/routers/pose_feedback.py rexx_server/tests/test_gemini_service.py
git commit -m "feat: Gemini 조건부 프롬프트 + 레이어 기반 3종 피드백 출력"
```

---

### Task 5: Flutter — LevelService 등급 관리 + 자동 제안 (TDD)

**Files:**
- Create: `rexx_app/lib/services/level_service.dart`
- Create: `rexx_app/test/services/level_service_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`rexx_app/test/services/level_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexx_app/services/level_service.dart';
import 'package:rexx_app/features/pose_evaluation/engine/layer_classifier.dart';

void main() {
  group('LevelService', () {
    late LevelService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = LevelService();
    });

    test('기본 등급은 beginner', () async {
      final level = await service.getCurrentLevel();
      expect(level, UserLevel.beginner);
    });

    test('등급 로컬 캐시 저장/조회', () async {
      await service.saveLocalLevel(UserLevel.intermediate);
      final level = await service.getCurrentLevel();
      expect(level, UserLevel.intermediate);
    });

    group('등급 제안 로직', () {
      test('초급→중급: 평균 80점 이상 3회 연속', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.beginner,
          recentScores: [82, 85, 80],
        );
        expect(suggestion, LevelSuggestion.upgrade);
      });

      test('중급→상급: 평균 85점 이상 3회 연속', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.intermediate,
          recentScores: [88, 90, 86],
        );
        expect(suggestion, LevelSuggestion.upgrade);
      });

      test('상급→중급: 평균 60점 미만 3회 연속 (엄격)', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.advanced,
          recentScores: [55, 50, 58],
        );
        expect(suggestion, LevelSuggestion.downgrade);
      });

      test('중급→초급: 평균 50점 미만 5회 연속 (보수적)', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.intermediate,
          recentScores: [45, 48, 42, 49, 40],
        );
        expect(suggestion, LevelSuggestion.downgrade);
      });

      test('중급→초급: 4회만이면 제안 안 함', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.intermediate,
          recentScores: [45, 48, 42, 49],
        );
        expect(suggestion, LevelSuggestion.none);
      });

      test('상급자는 이미 최고 등급이므로 승급 없음', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.advanced,
          recentScores: [95, 98, 92],
        );
        expect(suggestion, LevelSuggestion.none);
      });

      test('초급자는 이미 최저 등급이므로 하향 없음', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.beginner,
          recentScores: [30, 25, 20, 15, 10],
        );
        expect(suggestion, LevelSuggestion.none);
      });

      test('점수 부족하면 제안 없음', () {
        final suggestion = LevelService.checkLevelSuggestion(
          currentLevel: UserLevel.beginner,
          recentScores: [90, 95],
        );
        expect(suggestion, LevelSuggestion.none);
      });
    });

    group('제안 메시지', () {
      test('승급 메시지', () {
        final msg = LevelService.suggestionMessage(
          LevelSuggestion.upgrade,
          UserLevel.beginner,
        );
        expect(msg, contains('중급'));
      });

      test('상급→중급 하향 메시지', () {
        final msg = LevelService.suggestionMessage(
          LevelSuggestion.downgrade,
          UserLevel.advanced,
        );
        expect(msg, contains('평소와 다른 패턴'));
      });

      test('중급→초급 하향 메시지', () {
        final msg = LevelService.suggestionMessage(
          LevelSuggestion.downgrade,
          UserLevel.intermediate,
        );
        expect(msg, contains('세부적인 코칭'));
      });
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd rexx_app && flutter test test/services/level_service_test.dart
```

Expected: 컴파일 에러

- [ ] **Step 3: LevelService 구현**

`rexx_app/lib/services/level_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../features/pose_evaluation/engine/layer_classifier.dart';

enum LevelSuggestion { none, upgrade, downgrade }

class LevelService {
  static const String _levelKey = 'user_level';
  static const String _scoresKey = 'recent_scores';

  /// 로컬 캐시에서 현재 등급 조회
  Future<UserLevel> getCurrentLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_levelKey);
    return value != null ? UserLevel.fromString(value) : UserLevel.beginner;
  }

  /// 로컬 캐시에 등급 저장
  Future<void> saveLocalLevel(UserLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_levelKey, level.apiName);
  }

  /// 서버에 등급 변경 요청
  Future<bool> updateServerLevel(UserLevel level, String token) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/me/level'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'level': level.apiName}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await saveLocalLevel(level);
        return true;
      }
    } catch (e) {
      debugPrint('[LevelService] 등급 변경 실패: $e');
    }
    return false;
  }

  /// 최근 점수 저장 (로컬)
  Future<void> addScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final scores = prefs.getStringList(_scoresKey) ?? [];
    scores.add(score.toString());
    // 최근 10회만 유지
    if (scores.length > 10) {
      scores.removeRange(0, scores.length - 10);
    }
    await prefs.setStringList(_scoresKey, scores);
  }

  /// 최근 점수 조회
  Future<List<int>> getRecentScores() async {
    final prefs = await SharedPreferences.getInstance();
    final scores = prefs.getStringList(_scoresKey) ?? [];
    return scores.map((s) => int.parse(s)).toList();
  }

  /// 등급 변경 제안 확인 (순수 함수)
  static LevelSuggestion checkLevelSuggestion({
    required UserLevel currentLevel,
    required List<int> recentScores,
  }) {
    // 승급 체크
    if (currentLevel != UserLevel.advanced && recentScores.length >= 3) {
      final last3 = recentScores.sublist(recentScores.length - 3);
      final threshold = currentLevel == UserLevel.beginner ? 80 : 85;
      if (last3.every((s) => s >= threshold)) {
        return LevelSuggestion.upgrade;
      }
    }

    // 하향 체크
    if (currentLevel == UserLevel.advanced && recentScores.length >= 3) {
      final last3 = recentScores.sublist(recentScores.length - 3);
      if (last3.every((s) => s < 60)) {
        return LevelSuggestion.downgrade;
      }
    } else if (currentLevel == UserLevel.intermediate && recentScores.length >= 5) {
      final last5 = recentScores.sublist(recentScores.length - 5);
      if (last5.every((s) => s < 50)) {
        return LevelSuggestion.downgrade;
      }
    }

    return LevelSuggestion.none;
  }

  /// 제안 메시지 생성
  static String suggestionMessage(LevelSuggestion suggestion, UserLevel currentLevel) {
    if (suggestion == LevelSuggestion.upgrade) {
      final nextLevel = currentLevel == UserLevel.beginner
          ? UserLevel.intermediate
          : UserLevel.advanced;
      return '최근 자세가 안정적이에요! ${nextLevel.displayName}으로 올려볼까요?';
    }

    if (suggestion == LevelSuggestion.downgrade) {
      if (currentLevel == UserLevel.advanced) {
        return '최근 자세가 평소와 다른 패턴이 보여요. 중급 모드로 전환하면 더 구체적인 피드백을 받을 수 있어요.';
      } else {
        return '더 세부적인 코칭을 받아보시겠어요? 단계를 조정하면 원인과 수정 방법까지 안내해 드려요.';
      }
    }

    return '';
  }

  /// 제안 시 변경될 등급 반환
  static UserLevel suggestedLevel(LevelSuggestion suggestion, UserLevel currentLevel) {
    if (suggestion == LevelSuggestion.upgrade) {
      return currentLevel == UserLevel.beginner
          ? UserLevel.intermediate
          : UserLevel.advanced;
    }
    if (suggestion == LevelSuggestion.downgrade) {
      return currentLevel == UserLevel.advanced
          ? UserLevel.intermediate
          : UserLevel.beginner;
    }
    return currentLevel;
  }
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
cd rexx_app && flutter test test/services/level_service_test.dart
```

Expected: All tests PASS

- [ ] **Step 5: 커밋**

```bash
git add rexx_app/lib/services/level_service.dart rexx_app/test/services/level_service_test.dart
git commit -m "feat: LevelService 사용자 등급 관리 + 자동 제안 로직 (TDD)"
```

---

### Task 6: Flutter — EvaluationResult에 LayerClassification 통합

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/models/evaluation_result.dart:54-103`
- Modify: `rexx_app/lib/features/pose_evaluation/engine/pose_analyzer.dart:87-115`

- [ ] **Step 1: EvaluationResult에 layerClassification 필드 추가**

`rexx_app/lib/features/pose_evaluation/models/evaluation_result.dart`에서:

import 추가 (파일 상단):

```dart
import '../engine/layer_classifier.dart';
```

`EvaluationResult` 클래스 변경:

```dart
class EvaluationResult {
  final ExerciseType exerciseType;
  final int totalScore;
  final List<CriterionResult> criteria;
  final List<String> detectedIssues;
  final DateTime evaluatedAt;
  final String? feedbackText;
  final FeedbackError? feedbackError;
  final LayerClassification? layerClassification;

  const EvaluationResult({
    required this.exerciseType,
    required this.totalScore,
    required this.criteria,
    required this.detectedIssues,
    required this.evaluatedAt,
    this.feedbackText,
    this.feedbackError,
    this.layerClassification,
  });

  EvaluationResult copyWith({
    String? feedbackText,
    FeedbackError? feedbackError,
    LayerClassification? layerClassification,
  }) {
    return EvaluationResult(
      exerciseType: exerciseType,
      totalScore: totalScore,
      criteria: criteria,
      detectedIssues: detectedIssues,
      evaluatedAt: evaluatedAt,
      feedbackText: feedbackText ?? this.feedbackText,
      feedbackError: feedbackError ?? this.feedbackError,
      layerClassification: layerClassification ?? this.layerClassification,
    );
  }

  CriterionResult get worstCriterion {
    return criteria.reduce((a, b) => a.score < b.score ? a : b);
  }

  String get offlineFeedback {
    final worst = worstCriterion;
    return '총점 $totalScore점입니다. ${worst.description}에서 개선이 필요합니다. '
        '인터넷 연결 시 더 자세한 피드백을 받을 수 있습니다.';
  }

  Map<String, dynamic> toJson() => {
        'exercise_type': exerciseType.apiName,
        'total_score': totalScore,
        'criteria_scores': criteria.map((c) => c.toJson()).toList(),
        'detected_issues': detectedIssues,
      };
}
```

- [ ] **Step 2: PoseAnalyzer에 LayerClassifier 호출 추가**

`rexx_app/lib/features/pose_evaluation/engine/pose_analyzer.dart`에서:

import 추가:

```dart
import 'layer_classifier.dart';
```

`analyze` 메서드의 규칙 평가 후 (line 89, `final criteria = rule.evaluate(poseFrames);` 다음)에 레이어 분류 추가. `analyze` 메서드에 `LayerClassifier? layerClassifier` 파라미터 추가:

```dart
  Future<EvaluationResult> analyze({
    required String videoPath,
    ExerciseType? exerciseType,
    LayerClassifier? layerClassifier,
    Future<ExerciseType> Function(ClassificationResult)? onClassificationNeeded,
    void Function(ExerciseType)? onAutoClassified,
    void Function(double progress)? onProgress,
  }) async {
```

규칙 평가 후 (line 89 이후, 총점 계산 전):

```dart
    // 3.5 레이어 분류 (분류기 제공 시)
    LayerClassification? layerClassification;
    if (layerClassifier != null) {
      layerClassification = layerClassifier.classify(criteria, resolvedType);
    }
```

반환 객체에 추가:

```dart
    return EvaluationResult(
      exerciseType: resolvedType,
      totalScore: totalScore.round(),
      criteria: criteria,
      detectedIssues: issues,
      evaluatedAt: DateTime.now(),
      layerClassification: layerClassification,
    );
```

`analyzeWithDebug`에도 동일하게 `layerClassifier` 파라미터와 분류 로직 추가.

- [ ] **Step 3: 기존 테스트 통과 확인**

```bash
cd rexx_app && flutter test
```

Expected: All tests PASS (layerClassifier는 optional이므로 기존 호출에 영향 없음)

- [ ] **Step 4: 커밋**

```bash
git add rexx_app/lib/features/pose_evaluation/models/evaluation_result.dart rexx_app/lib/features/pose_evaluation/engine/pose_analyzer.dart
git commit -m "feat: EvaluationResult에 LayerClassification 통합"
```

---

### Task 7: Flutter — PoseFeedbackService 레이어 데이터 전송

**Files:**
- Modify: `rexx_app/lib/services/pose_feedback_service.dart:76-134`

- [ ] **Step 1: toJson에 레이어 데이터 추가**

`rexx_app/lib/features/pose_evaluation/models/evaluation_result.dart`의 `toJson` 메서드 변경:

```dart
  Map<String, dynamic> toJson({String userLevel = 'beginner'}) => {
        'exercise_type': exerciseType.apiName,
        'total_score': totalScore,
        'criteria_scores': criteria.map((c) => c.toJson()).toList(),
        'detected_issues': detectedIssues,
        'user_level': userLevel,
        'layer1_issues': layerClassification?.layer1Issues
                .map((i) => i.toJson())
                .toList() ??
            [],
        'layer2_issues': layerClassification?.layer2Issues
                .map((i) => i.toJson())
                .toList() ??
            [],
      };
```

- [ ] **Step 2: PoseFeedbackService에 userLevel 파라미터 추가**

`rexx_app/lib/services/pose_feedback_service.dart`의 `requestFeedback` 시그니처 변경:

```dart
  Future<FeedbackResult> requestFeedback({
    required EvaluationResult result,
    required String? token,
    String userLevel = 'beginner',
  }) async {
```

그리고 body 전송 부분 (line 103-104) 변경:

```dart
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/pose/feedback'),
        headers: headers,
        body: jsonEncode(result.toJson(userLevel: userLevel)),
      ).timeout(const Duration(seconds: 30));
```

- [ ] **Step 3: 기존 테스트 통과 확인**

```bash
cd rexx_app && flutter test
```

Expected: All tests PASS (userLevel은 기본값이 있으므로 기존 호출에 영향 없음)

- [ ] **Step 4: 커밋**

```bash
git add rexx_app/lib/features/pose_evaluation/models/evaluation_result.dart rexx_app/lib/services/pose_feedback_service.dart
git commit -m "feat: PoseFeedbackService에 레이어+등급 데이터 전송 추가"
```

---

### Task 8: Flutter — FeedbackCard 3종 포맷 + 조건부 스타일

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/widgets/feedback_card.dart`

- [ ] **Step 1: FeedbackCard에 레이어 정보 전달 + 3종 포맷**

`rexx_app/lib/features/pose_evaluation/widgets/feedback_card.dart`를 전체 교체:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/pose_feedback_service.dart';
import '../engine/layer_classifier.dart';

/// AI 코칭 피드백 카드 위젯 (3종 구조화 JSON 표시)
class FeedbackCard extends StatelessWidget {
  final String? feedbackText;
  final String offlineFeedback;
  final FeedbackError? error;
  final LayerClassification? layerClassification;

  const FeedbackCard({
    super.key,
    this.feedbackText,
    required this.offlineFeedback,
    this.error,
    this.layerClassification,
  });

  static const Color card = Color(0xFF0F1612);
  static const Color primary = Color(0xFF16A34A);
  static const Color danger = Color(0xFFEF4444);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  /// feedbackText를 JSON으로 파싱 시도
  Map<String, dynamic>? _parseFeedback() {
    if (feedbackText == null) return null;
    try {
      final parsed = jsonDecode(feedbackText!);
      if (parsed is Map<String, dynamic>) {
        // 3종 포맷 (feedback/keypoint/cause) 또는 구형 포맷 (summary/reason/action/cue)
        if (parsed.containsKey('feedback') || parsed.containsKey('summary')) {
          return parsed;
        }
      }
    } catch (_) {}
    return null;
  }

  bool get _isLayer1 => layerClassification?.hasLayer1 ?? false;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseFeedback();
    final isOnline = feedbackText != null;

    // 빈 피드백 (상급+L2만 또는 이슈 없음)
    if (parsed != null && _isEmptyFeedback(parsed)) {
      return _buildNoIssueFeedback();
    }

    // 구조화된 JSON 피드백
    if (parsed != null) {
      return _buildStructuredFeedback(parsed);
    }

    // 일반 텍스트 피드백 (fallback)
    return _buildPlainFeedback(isOnline);
  }

  bool _isEmptyFeedback(Map<String, dynamic> data) {
    final feedback = data['feedback'] as String? ?? '';
    final keypoint = data['keypoint'] as String? ?? '';
    return feedback.isEmpty && keypoint.isEmpty;
  }

  Widget _buildNoIssueFeedback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: primary, size: 48),
          const SizedBox(height: 12),
          const Text(
            '자세가 좋습니다!',
            style: TextStyle(
              color: textMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '현재 자세를 유지하면서 연습하세요.',
            style: TextStyle(color: textSub, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStructuredFeedback(Map<String, dynamic> data) {
    // 3종 포맷 우선, 구형 폴백
    final feedback = data['feedback'] as String? ?? data['summary'] as String? ?? '';
    final keypoint = data['keypoint'] as String? ?? data['cue'] as String? ?? '';
    final cause = data['cause'] as String? ?? data['reason'] as String? ?? '';

    final accentColor = _isLayer1 ? danger : primary;

    return Column(
      children: [
        // 한 줄 키포인트 — 상단 강조
        if (keypoint.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  _isLayer1 ? Icons.warning_amber_rounded : Icons.format_quote,
                  color: Colors.white70,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  keypoint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
                if (_isLayer1) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ 부상 위험',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),

        // 자세 문제 원인
        if (cause.isNotEmpty)
          _buildSection(
            icon: Icons.search,
            title: '자세 문제 원인',
            content: cause,
          ),
        if (cause.isNotEmpty) const SizedBox(height: 12),

        // 피드백 (상세 설명)
        if (feedback.isNotEmpty)
          _buildSection(
            icon: Icons.directions_run,
            title: '피드백',
            content: feedback,
            highlight: true,
          ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlight ? primary.withValues(alpha: 0.08) : card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? primary.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: highlight ? primary : textSub, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: highlight ? primary : textSub,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: textMain,
              fontSize: 16,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainFeedback(bool isOnline) {
    final displayText = feedbackText ?? offlineFeedback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.smart_toy : Icons.info_outline,
                color: isOnline ? primary : textSub,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'AI 코칭 피드백' : '기본 피드백',
                style: TextStyle(
                  color: isOnline ? primary : textSub,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayText,
            style: const TextStyle(
              color: textMain,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          if (!isOnline) ...[
            const SizedBox(height: 12),
            _buildErrorHint(),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorHint() {
    final errorInfo = _getErrorInfo();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: errorInfo.bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(errorInfo.icon, color: errorInfo.iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorInfo.message,
              style: TextStyle(
                color: errorInfo.iconColor,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ErrorInfo _getErrorInfo() {
    switch (error) {
      case FeedbackError.offline:
        return _ErrorInfo(
          icon: Icons.wifi_off,
          iconColor: const Color(0xFFF59E0B),
          bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          message: '네트워크에 연결되면 AI 코칭 피드백을 받을 수 있습니다.',
        );
      case FeedbackError.noToken:
        return _ErrorInfo(
          icon: Icons.lock_outline,
          iconColor: const Color(0xFF60A5FA),
          bgColor: const Color(0xFF60A5FA).withValues(alpha: 0.1),
          message: '로그인 후 AI 코칭 피드백을 이용할 수 있습니다.',
        );
      case FeedbackError.apiError:
        return _ErrorInfo(
          icon: Icons.cloud_off,
          iconColor: const Color(0xFFEF4444),
          bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
          message: 'AI 서비스에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        );
      case FeedbackError.timeout:
        return _ErrorInfo(
          icon: Icons.timer_off,
          iconColor: const Color(0xFFF97316),
          bgColor: const Color(0xFFF97316).withValues(alpha: 0.1),
          message: '서버 응답이 지연되고 있습니다. 네트워크 상태를 확인해 주세요.',
        );
      case FeedbackError.guestLimitReached:
        return _ErrorInfo(
          icon: Icons.card_giftcard,
          iconColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          message: '무료 AI 코칭 체험이 끝났어요. 회원가입하면 무제한으로 이용할 수 있습니다!',
        );
      case FeedbackError.unknown:
      case null:
        return _ErrorInfo(
          icon: Icons.info_outline,
          iconColor: textSub,
          bgColor: Colors.white.withValues(alpha: 0.05),
          message: '인터넷 연결 시 AI 피드백을 받을 수 있습니다.',
        );
    }
  }
}

class _ErrorInfo {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String message;

  const _ErrorInfo({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.message,
  });
}
```

- [ ] **Step 2: PoseResultScreen에서 FeedbackCard에 layerClassification 전달**

`rexx_app/lib/features/pose_evaluation/screens/pose_result_screen.dart`의 FeedbackCard 호출 (line 91-95) 변경:

```dart
              FeedbackCard(
                feedbackText: widget.result.feedbackText,
                offlineFeedback: widget.result.offlineFeedback,
                error: widget.result.feedbackError,
                layerClassification: widget.result.layerClassification,
              ),
```

- [ ] **Step 3: 기존 테스트 통과 확인**

```bash
cd rexx_app && flutter test
```

- [ ] **Step 4: 커밋**

```bash
git add rexx_app/lib/features/pose_evaluation/widgets/feedback_card.dart rexx_app/lib/features/pose_evaluation/screens/pose_result_screen.dart
git commit -m "feat: FeedbackCard 3종 포맷 + L1 경고 스타일 리디자인"
```

---

### Task 9: Flutter — VideoUploadScreen에 레이어 분류 + 출력 결정 통합

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/screens/video_upload_screen.dart:151-310`

- [ ] **Step 1: VideoUploadScreen에 LayerClassifier + LevelService 통합**

`rexx_app/lib/features/pose_evaluation/screens/video_upload_screen.dart`에서:

import 추가:

```dart
import '../engine/layer_classifier.dart';
import '../../../services/level_service.dart';
```

`_startAnalysis` 메서드를 변경. 핵심 변경 부분 (analyzer 호출 전후):

```dart
  Future<void> _startAnalysis() async {
    if (_videoPath == null) return;

    final exerciseType = widget.exerciseType ?? _selectedExerciseType;
    if (exerciseType == null) {
      _showExercisePickerBottomSheet();
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _progress = 0.0;
      _statusText = '프레임 추출 중...';
    });

    try {
      final analyzer = PoseAnalyzer();
      final layerClassifier = await LayerClassifier.load();
      final levelService = LevelService();
      final userLevel = await levelService.getCurrentLevel();

      void onProgress(double progress) {
        setState(() {
          _progress = progress;
          if (progress < 0.3) {
            _statusText = '프레임 추출 중...';
          } else if (progress < 0.7) {
            _statusText = '포즈 감지 중...';
          } else {
            _statusText = '점수 계산 중...';
          }
        });
      }

      if (_debugMode) {
        final debugData = await analyzer.analyzeWithDebug(
          videoPath: _videoPath!,
          exerciseType: exerciseType,
          layerClassifier: layerClassifier,
          onProgress: onProgress,
        );
        analyzer.dispose();

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PoseDebugScreen(debugData: debugData),
          ),
        );

        if (!mounted) return;

        final result = debugData.result;
        final classification = result.layerClassification;

        // 등급 기반 출력 결정
        if (classification != null && !classification.shouldRequestFeedback(userLevel)) {
          // 서버 호출 스킵
          final finalResult = result.copyWith(
            feedbackText: '{"feedback":"","keypoint":"","cause":""}',
          );
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PoseResultScreen(result: finalResult, token: widget.token),
            ),
          );
          return;
        }

        setState(() { _statusText = '피드백 생성 중...'; });

        final feedbackService = PoseFeedbackService();
        final feedbackResult = await feedbackService.requestFeedback(
          result: result,
          token: widget.token,
          userLevel: userLevel.apiName,
        );

        final finalResult = feedbackResult.isSuccess
            ? result.copyWith(feedbackText: feedbackResult.feedback)
            : result.copyWith(feedbackError: feedbackResult.error);

        // 점수 저장 (등급 제안용)
        await levelService.addScore(result.totalScore);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PoseResultScreen(result: finalResult, token: widget.token),
          ),
        );
        return;
      }

      final result = await analyzer.analyze(
        videoPath: _videoPath!,
        exerciseType: exerciseType,
        layerClassifier: layerClassifier,
        onProgress: onProgress,
      );

      analyzer.dispose();

      final classification = result.layerClassification;

      // 등급 기반 출력 결정
      if (classification != null && !classification.shouldRequestFeedback(userLevel)) {
        final finalResult = result.copyWith(
          feedbackText: '{"feedback":"","keypoint":"","cause":""}',
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PoseResultScreen(result: finalResult, token: widget.token),
          ),
        );
        return;
      }

      setState(() { _statusText = '피드백 생성 중...'; });

      final feedbackService = PoseFeedbackService();
      final feedbackResult = await feedbackService.requestFeedback(
        result: result,
        token: widget.token,
        userLevel: userLevel.apiName,
      );

      final finalResult = feedbackResult.isSuccess
          ? result.copyWith(feedbackText: feedbackResult.feedback)
          : result.copyWith(feedbackError: feedbackResult.error);

      // 점수 저장 (등급 제안용)
      await levelService.addScore(result.totalScore);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PoseResultScreen(result: finalResult, token: widget.token),
        ),
      );
    } on _ClassificationCancelledException {
      setState(() { _isAnalyzing = false; _statusText = ''; });
      return;
    } catch (e) {
      setState(() { _isAnalyzing = false; _statusText = ''; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 실패: $e')),
      );
    }
  }
```

- [ ] **Step 2: flutter analyze 통과 확인**

```bash
cd rexx_app && flutter analyze
```

- [ ] **Step 3: 커밋**

```bash
git add rexx_app/lib/features/pose_evaluation/screens/video_upload_screen.dart
git commit -m "feat: VideoUploadScreen에 레이어 분류 + 출력 결정 로직 통합"
```

---

### Task 10: 등급 변경 제안 바텀시트 + 결과 화면 트리거

**Files:**
- Create: `rexx_app/lib/features/pose_evaluation/widgets/level_suggestion_sheet.dart`
- Modify: `rexx_app/lib/features/pose_evaluation/screens/pose_result_screen.dart`

- [ ] **Step 1: LevelSuggestionSheet 위젯 생성**

`rexx_app/lib/features/pose_evaluation/widgets/level_suggestion_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../services/level_service.dart';
import '../engine/layer_classifier.dart';

class LevelSuggestionSheet {
  static Future<bool?> show(
    BuildContext context, {
    required LevelSuggestion suggestion,
    required UserLevel currentLevel,
  }) {
    final message = LevelService.suggestionMessage(suggestion, currentLevel);
    final targetLevel = LevelService.suggestedLevel(suggestion, currentLevel);

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF0F1612),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: suggestion == LevelSuggestion.upgrade
                      ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  suggestion == LevelSuggestion.upgrade
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: suggestion == LevelSuggestion.upgrade
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE9F5EF),
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '등급은 설정에서 언제든 변경할 수 있습니다.',
                style: TextStyle(
                  color: const Color(0xFFA7B9B0),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA7B9B0),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('유지할게요'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('${targetLevel.displayName}으로 변경'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: PoseResultScreen에서 등급 제안 트리거**

`rexx_app/lib/features/pose_evaluation/screens/pose_result_screen.dart`에서:

import 추가:

```dart
import '../../../services/level_service.dart';
import '../engine/layer_classifier.dart';
import '../widgets/level_suggestion_sheet.dart';
```

`initState`에서 등급 제안 확인:

```dart
class _PoseResultScreenState extends State<PoseResultScreen> {
  static const Color bg = Color(0xFF0B0F0C);
  static const Color textMain = Color(0xFFE9F5EF);
  bool get _isGuest => widget.token == null;

  @override
  void initState() {
    super.initState();
    if (!_isGuest) {
      _checkLevelSuggestion();
    }
  }

  Future<void> _checkLevelSuggestion() async {
    final levelService = LevelService();
    final currentLevel = await levelService.getCurrentLevel();
    final recentScores = await levelService.getRecentScores();

    final suggestion = LevelService.checkLevelSuggestion(
      currentLevel: currentLevel,
      recentScores: recentScores,
    );

    if (suggestion == LevelSuggestion.none || !mounted) return;

    // 약간의 딜레이 후 표시 (결과 화면이 먼저 보이도록)
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final accepted = await LevelSuggestionSheet.show(
      context,
      suggestion: suggestion,
      currentLevel: currentLevel,
    );

    if (accepted == true && widget.token != null) {
      final newLevel = LevelService.suggestedLevel(suggestion, currentLevel);
      await levelService.updateServerLevel(newLevel, widget.token!);
    }
  }
```

- [ ] **Step 3: flutter analyze 통과 확인**

```bash
cd rexx_app && flutter analyze
```

- [ ] **Step 4: 커밋**

```bash
git add rexx_app/lib/features/pose_evaluation/widgets/level_suggestion_sheet.dart rexx_app/lib/features/pose_evaluation/screens/pose_result_screen.dart
git commit -m "feat: 등급 변경 제안 바텀시트 + 결과 화면 트리거"
```

---

### Task 11: 전체 통합 테스트 + 정리

**Files:**
- All test files

- [ ] **Step 1: Flutter 전체 테스트**

```bash
cd rexx_app && flutter test
```

Expected: All tests PASS

- [ ] **Step 2: Flutter 정적 분석**

```bash
cd rexx_app && flutter analyze
```

Expected: No issues found

- [ ] **Step 3: 서버 전체 테스트**

```bash
cd rexx_server && python -m pytest -v
```

Expected: All tests PASS

- [ ] **Step 4: 최종 커밋 (필요 시)**

누락된 파일이 있으면 추가 커밋.

```bash
git status
```
