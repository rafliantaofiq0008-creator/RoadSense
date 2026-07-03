# Database Schema

## Supabase-Only Architecture
RoadSense uses a Supabase-only architecture. All sensor data is buffered in memory during a trip and immediately pushed to the cloud in batches. There is no local SQLite database.

## Supabase Tables (Remote)
1. `profiles`: Extended user profile info (linked to auth.users).
2. `road_sessions`: Stores user trip sessions (e.g. start time, end time, summary statistics).
3. `road_readings`: Stores detailed sensor readings tied to a session. Generated at 1-second intervals.
4. `road_events`: Stores detected anomalies (e.g. potholes, bumps) tied to a session.

### Batching & Interval Sampling
Raw readings (accelerometer, GPS) are generated at high frequencies in the UI. For trip recording, they are sampled at a dedicated 1-second interval before being saved as a combined `RoadReading` to an in-memory buffer. These buffered readings and events are then batched and uploaded to Supabase every 5 seconds. This drastically minimizes network overhead and API calls.

### Map Coordinate Derivation
The Map Visualization exclusively queries `road_readings` and `road_events` from Supabase:
- **Route Polyline**: Drawn using the sequenced `latitude` and `longitude` fields from `road_readings`.
- **Event Markers**: Plotted using the `latitude` and `longitude` fields from `road_events`. Missing or invalid coordinates (`null`, out-of-bounds) are safely discarded during rendering.

## Row Level Security (RLS) Policies
- Enabled on `profiles`, `road_sessions`, `road_readings`, and `road_events`.
- Enforces strict isolation: `auth.uid() = user_id`.
- For `profiles`, users can only read/update their own profile via `auth.uid() = id`.
- Service role keys are explicitly banned in the Flutter app to maintain security integrity.
