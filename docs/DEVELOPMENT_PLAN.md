# Development Plan

## Phase 1: Infrastructure Setup (Completed)
- [x] Scaffold Flutter project and directories.
- [x] Configure dependencies and `.env` setup.

## Phase 2: Data layer hardening (Completed)
- [x] Configure cloud database schema on Supabase.
- [x] Implement APIs and `TripRecorderService`.

## Phase 3: Supabase Authentication (Completed)
- [x] Implement Supabase Auth flow (Login, Register).
- [x] Handle session state.
- [x] Create and manage user profiles in Supabase.

## Phase 4: Accelerometer real-time preview (Completed)
- [x] Implement `AccelerometerService` to capture x, y, z data.
- [x] Differentiate user accelerometer and raw accelerometer.
- [x] Visualize vibration live with `fl_chart`.

## Phase 5: GPS tracking and speed preview (Completed)
- [x] Implement `LocationService` with `geolocator`.
- [x] Handle foreground location permissions securely.
- [x] Preview GPS data and movement status alongside vibration.

## Phase 6: Cloud trip recording (Completed)
- [x] Wire up Supabase to save trip sessions and readings.
- [x] Implement controlled 1-second sampling and 5-second batch upload.
- [x] Add Readiness Validator (prevents empty cloud sessions).

## Phase 7: Pothole detection engine (Completed)
- [x] Refine `PotholeDetectionService` with cooldown and threshold logic.
- [x] Record detected anomalies to cloud buffers.
- [x] Update UI with Detection Status.

### Phase 11: Road Photo Evidence & PDF Report Export (Completed)
- **Goal**: Enable photo evidence capture and generate exportable PDF reports.
- **Tasks**:
  - [x] Implement `road_photos` Supabase table and Storage Bucket policies.
  - [x] Add 'Take Photo' capture to Live Tracking and Trip Detail retroactively.
  - [x] Update Edge Function AI prompt to include photo metadata evidence.
  - [x] Implement local Flutter PDF generation combining Markdown and Photo assets.

## Phase 8: Cloud Native Migration (Completed)
- [x] Remove SQLite.
- [x] Upload batched readings and events directly.

## Phase 9: Supabase Map Visualization (Completed)
- [x] Integrate `flutter_map` with OpenStreetMap.
- [x] Visualize trip routes using `road_readings`.
- [x] Display road anomalies as markers using `road_events`.
- [x] Build map navigation from Dashboard, History, and Trip Details.

## Phase 10: AI Road Damage Scientific Report (Completed)
- [x] Create `ai_reports` table with RLS.
- [x] Implement Edge Function to call Gemini 2.5 Flash for report generation.
- [x] Integrate UI to generate, view, and copy scientific reports.
- [x] Use deterministic data analytics for AI prompting.
