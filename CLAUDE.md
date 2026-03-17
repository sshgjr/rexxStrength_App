# CLAUDE.md

> **⚠️ IMPORTANT — Language Policy: Always reason and think internally in English for deeper, more creative problem-solving, regardless of the language the user writes in. However, all user-facing output (UI text, code comments, console messages, error messages) MUST be written in Korean (한국어).**

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rexx Strength is a fitness app where users upload exercise videos (squat, bench press, deadlift) to get pose evaluation scores and AI coaching feedback. The evaluation pipeline runs locally on-device; only the text feedback generation hits the server.

## Architecture

```
Flutter App (rexx_app/)                    FastAPI Backend (rexx_server/)
┌─────────────────────────────┐           ┌──────────────────────────────┐
│ Video → FFmpeg (5fps frames)│           │ auth.py    — User model, JWT │
│ → ML Kit BlazePose          │           │ database.py — SQLAlchemy/SQLite│
│ → Rule engine (Dart, local) │  online   │ routers/pose_feedback.py     │
│ → Score shown immediately   │──────────→│   POST /api/pose/feedback    │
│                             │           │   → Claude Haiku → feedback  │
│ Offline: fallback text      │           │   → stores in pose_evaluations│
└─────────────────────────────┘           └──────────────────────────────┘
```

**Key design decisions:**
- Pose extraction + scoring run entirely on-device (offline capable)
- Only text feedback generation requires network (Claude Haiku API)
- Rule-based scoring via `ExerciseRule` interface — one implementation per exercise type
- Offline results queued in SharedPreferences, synced when reconnected

## Build & Run Commands

### Backend
```bash
cd rexx_server
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Flutter
```bash
cd rexx_app
flutter pub get
flutter run                    # Run on connected device/simulator
flutter analyze                # Dart static analysis (linting)
flutter test                   # Run unit tests
flutter test test/path_test.dart  # Run single test file
```

### API URL Configuration
- iOS simulator: `http://127.0.0.1:8000` (default in `lib/config/api_config.dart`)
- Android emulator: change to `http://10.0.2.2:8000`

## Code Architecture

### Flutter (`rexx_app/lib/`)
- `main.dart` — App entry point only (delegates to `pages/home_screen.dart`)
- `config/` — API base URL
- `pages/` — Top-level screens (home, login, member)
- `services/` — HTTP clients (`auth_service.dart`, `pose_feedback_service.dart`)
- `features/pose_evaluation/` — Self-contained feature module:
  - `models/` — `PoseFrame` (33 BlazePose landmarks), `EvaluationResult`, `ExerciseType` enum
  - `engine/` — `PoseAnalyzer` orchestrator, `AngleCalculator` (3D vector math), `PhaseDetector`
  - `engine/rules/` — `ExerciseRule` interface + `SquatRules`, `BenchPressRules`, `DeadliftRules`
  - `screens/` — Exercise select → video upload → result display
  - `widgets/` — `ScoreGauge`, `CriterionBreakdown`, `FeedbackCard`

### Backend (`rexx_server/`)
- `main.py` — FastAPI app, auth endpoints, includes pose router
- `auth.py` — `User` SQLAlchemy model, JWT creation/validation, password hashing (extracted to avoid circular imports)
- `database.py` — Shared SQLAlchemy `Base`, `engine`, `get_db()` dependency
- `routers/pose_feedback.py` — `/api/pose/feedback` and `/api/pose/history`
- `services/haiku_service.py` — Claude Haiku API call with template fallback
- `models/pose_models.py` — `PoseEvaluation` table (scores stored as JSON text columns)
- `schemas/pose_schemas.py` — Pydantic request/response models

## Adding a New Exercise Type

1. Create `rexx_app/lib/features/pose_evaluation/engine/rules/new_exercise_rules.dart` implementing `ExerciseRule`
2. Add enum value to `ExerciseType` in `models/exercise_phase.dart`
3. Add case to `PoseAnalyzer._getRule()` switch
4. Add card in `ExerciseSelectScreen`

## Environment Variables (`rexx_server/.env`)

```
SECRET_KEY=...                    # JWT signing key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
DATABASE_URL=postgresql://...      # 필수 — Railway PostgreSQL 연결 URL
ANTHROPIC_API_KEY=sk-ant-...      # Required for AI feedback
```

## API Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | /register | No | Create account |
| POST | /login | No | Get JWT token |
| GET | /me | Yes | Current user info |
| POST | /api/pose/feedback | Yes | Submit scores, get AI feedback |
| GET | /api/pose/history | Yes | User's past evaluations |

## Scoring System

Each exercise has 5 weighted criteria (weights sum to 1.0). Per-criterion grades: Good (85-100), Warning (50-84), Bad (0-49). Total score = weighted average. The `AngleCalculator` uses 3D vector dot product for joint angles and linear interpolation for range-based scoring.

## Platform Requirements

- Android: `minSdk 24` (ML Kit requirement), `READ_MEDIA_VIDEO` permission
- iOS: `NSPhotoLibraryUsageDescription` in Info.plist
- ML Kit pose detection requires a physical device (limited emulator support)

## UI Theme

Dark green theme — bg: `#0B0F0C`, card: `#0F1612`, primary: `#16A34A`, text: `#E9F5EF`, sub: `#A7B9B0`. All UI is in Korean.
