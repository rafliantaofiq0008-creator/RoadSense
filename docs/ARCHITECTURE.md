# Architecture Overview

## Environment Variable Setup
Secrets like `SUPABASE_URL` and `SUPABASE_ANON_KEY` are read securely via `String.fromEnvironment`. 
To run the app properly, you must use `--dart-define`:
```bash
flutter run --dart-define=SUPABASE_URL=your-url --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Authentication and Routing Flow
- **Supabase Auth**: Email/password authentication is provided by `Supabase.instance.client.auth`, abstracted via `AuthService`.
- **Profile Creation**: An auto-profile trigger in Supabase automatically creates a record in the `profiles` table on `auth.users` insert, using metadata `full_name`.
- **Email Confirmation**:
  - **Dev Option**: You can disable "Confirm Email" in Supabase Auth settings for local development.
  - **Production Option**: Use the provided trigger. Registration will return a null session until the user clicks the confirmation link, which the app handles gracefully.
- **Protected Routing**: `app.dart` uses a `StreamBuilder` listening to `AuthService().authStateChanges`. 
  - Restores session automatically at startup.
  - Redirects unauthenticated users to `LoginPage`.
  - Redirects authenticated users to `DashboardPage`.

## Cloud-Native Architecture
RoadSense uses a Supabase-only architecture. Data is captured and buffered in memory before being pushed to the cloud in batches.
- **Why SQLite was removed**: A local database added unnecessary complexity for the MVP scope. A direct-to-cloud approach is simpler to maintain and ensures immediate data visibility.
- **Batching**: Readings are batched in memory and uploaded every 5 seconds (or upon reaching a buffer limit) to prevent overwhelming the network with individual API calls.

## Sensor Data Flow
1. **Acceleromater & Location Services:** Stream raw readings.
2. **TripRecorderService:** Periodically samples the latest vibration and GPS data (via a dedicated 1-second timer) to combine them into a `RoadReading` and save to an in-memory buffer. The 1-second interval avoids overwhelming database sizes compared to saving raw 100ms UI frames, while providing sufficient granularity for pothole mapping.
3. **PotholeDetectionService:** Evaluates data in real time using every `VibrationSample` and the latest `LocationSample`. It applies thresholds and cooldowns, returning a `PotholeDetectionResult`. This is then converted to a `RoadEvent` and buffered.
4. **Batch Upload:** `TripRecorderService` flushes its in-memory reading and event buffers to Supabase every 5 seconds.
5. **PdfReportExportService**: Handles conversion of markdown AI reports and associated road photos into a structured PDF document.

## Supabase Boundary and Initialization
Supabase configuration is strictly handled through the `SupabaseConfig` and `SupabaseService` classes. The initialization boundary ensures the client is instantiated only once at startup and that missing environment variables throw immediate errors. Service logic operates independently of how the client was formed.

## Postponed Background Tracking
Advanced features like background tracking, Isolates, and live machine learning are intentionally postponed in the current phase. The priority is to harden the foundational data layer (SQLite mapping, DAOs, and API integrations) and ensure a robust Supabase Sync before introducing complex async concurrency limitations and OS background restrictions.

## Accelerometer Live Tracking (Preview)
- **User Accelerometer**: We prefer `userAccelerometerEventStream()` from `sensors_plus` because it isolates acceleration applied by the user/device, automatically factoring out gravity. This reduces the need for complex baseline gravity calibration.
- **Magnitude**: Calculated as `sqrt(x^2 + y^2 + z^2)`.
- **Vibration Preview**: Calculated as `abs(magnitude - baseline)`. For `userAccelerometer`, magnitude naturally approaches 0 when stationary. 
- **Temporary Thresholds**: `vibration < 1.5` (Smooth), `< 3.0` (Bumpy), `>= 3.0` (High Vibration). These are placeholders for calibration.

## Cloud Trip Recording & Readiness
- **Recording Readiness**: Supabase-only recording requires valid sensor data. Recording cannot start until the accelerometer is streaming data and GPS accuracy is acceptable.
- **Controlled Interval**: `TripRecorderService` saves combined `RoadReading` objects (vibration + speed/location) every 1 second, discarding low-accuracy GPS data (>25m).
- **Empty Sessions**: Empty cloud sessions (where no readings or events were successfully uploaded) are prevented or automatically discarded upon stopping the trip.
- **Summary Updates**: On stopping a trip, `TripRecorderService` queries the saved readings to compute average speed, max speed, and max vibration, then updates the session.
- **Device Requirements**: Browser testing may not provide accelerometer data. An Android physical device is required for real sensor validation.

## GPS Tracking & Speed Preview
- **Foreground Only**: Location permissions are requested only when starting the preview. `ACCESS_BACKGROUND_LOCATION` is strictly avoided in this phase.
- **Speed Conversion**: Raw speed is captured in m/s and converted to km/h using a pure function `metersPerSecondToKmh()`.
- **Movement Threshold**: The vehicle is considered "Moving" when speed is $\ge$ 5.0 km/h. This is crucial for filtering out stationary noise.
- **Accuracy Threshold**: GPS accuracy must be $\le$ 25.0 meters to be considered "Good". Data outside this threshold will eventually be rejected by the detection engine.
- **Why GPS Precedes Detection**: The pothole detection engine requires both a minimum speed and good GPS accuracy to prevent false positives while stationary or indoors.

## Detection Engine Overview
The PotholeDetectionService identifies bumps/potholes using threshold-based detection:
- **Continuous Evaluation**: Detection evaluates every raw vibration sample instead of just the 1-second interval, because anomaly spikes may be extremely short and could be missed if only checked once per second.
- **Thresholds**: `vibration >= 3.0` (damaged), `>= 5.0` (pothole), `>= 8.0` (severe_pothole).
- **Speed Validation**: Rejects detections below a minimum speed (5 km/h) to filter out stationary shaking (e.g. entering the vehicle).
- **GPS Validation**: Rejects detections with poor GPS accuracy (> 25m).
- **Cooldown Logic**: A 3-second cooldown is enforced between recorded events to prevent duplicate event spamming over a single long anomaly.
- **Lifecycle**: Detected events are saved as `RoadEvent` to the in-memory buffer and flushed to Supabase dynamically.

## Supabase Map Visualization
- **Data Flow**: The Map Visualization strictly consumes cloud data from Supabase.
  - `road_readings`: Raw vibration and GPS samples generated every second
  - `road_events`: Automatically detected road anomalies (potholes, damaged roads)
  - `ai_reports`: AI-generated scientific reports in markdown format
  - `road_photos`: Metadata for visual photo evidence attached to trips
- **Supabase Storage**
  - `road-photos` bucket: Stores secure, private road images associated with sessions.
- **RLS Protection**: Because it relies on `RoadSessionApi`, `RoadReadingApi`, and `RoadEventApi`, map data is protected by Row Level Security (RLS) ensuring users can only fetch and view their own trips.
- **Map Display**: Uses `flutter_map` with OpenStreetMap tiles. Missing or invalid coordinates are safely filtered out using pure functions in `map_utils.dart`.
- **Requirements**: Plotting a route requires a minimum of 2 valid GPS readings. Recording longer trips on a real Android device naturally produces better map visualizations, whereas simulator testing or brief 5-second recordings will yield only a few points.

## AI Road Damage Scientific Report
- **Supabase Edge Functions**
  - `generate-road-report`: Aggregates trip data (readings, events, photos) and securely calls Google Gemini AI API to generate a structured markdown report.
- **Data Aggregation**: Before calling the AI, the app aggregates trip data using `RoadReportAnalyzer`, creating a deterministic JSON summary of distance, speeds, and events segmented every 500m.
- **Reporting Standard**: The AI prompt is strictly instructed to generate formal, scientific Indonesian language suitable for government entities (e.g., Diskominfo, Dinas PUPR) while explicitly noting that data is sensor-based and requires field verification.

## Privacy and Permission Boundary
The app strictly respects privacy by requesting permissions only when necessary:
- Location permissions are requested securely.
- Tracking does not occur without explicit foreground permission.
