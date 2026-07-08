# Database Schema

## Supabase-Only Architecture
RoadSense uses a Supabase-only architecture. All sensor data is buffered in memory during a trip and immediately pushed to the cloud in batches. There is no local SQLite database.

## Supabase Tables (Remote)
1. `profiles`: Extended user profile info (linked to auth.users).
2. `road_sessions`: Stores user trip sessions (e.g. start time, end time, summary statistics).
3. `road_readings`: Stores detailed sensor readings tied to a session. Generated at 1-second intervals.
4. `road_events`: Stores detected anomalies (e.g. potholes, bumps) tied to a session.
5. `ai_reports`: Stores AI-generated scientific reports derived from session data, tied to a session and user.
6. `road_photos`: Stores metadata for road photos, with files stored in Supabase Storage.

## 6. Table: `public.road_photos`
Tabel untuk merekam metadata bukti foto jalan, di mana file aslinya disimpan di bucket Supabase Storage.

| Column | Type | Nullable | Description |
|---|---|---|---|
| id | uuid | false | Primary key (default `gen_random_uuid()`) |
| user_id | uuid | false | Referensi ke `auth.users(id)` |
| session_id | uuid | false | Referensi ke `road_sessions(id)` |
| event_id | uuid | true | (Opsional) Referensi ke `road_events(id)` |
| segment_index | integer | true | (Opsional) Indeks segmen jalan |
| storage_bucket | text | false | Nama storage bucket (default `road-photos`) |
| storage_path | text | false | Path relatif file foto di storage bucket |
| latitude | double precision | true | Lintang saat difoto |
| longitude | double precision | true | Bujur saat difoto |
| gps_accuracy | double precision | true | Akurasi GPS |
| speed | double precision | true | Kecepatan sesaat |
| vibration | double precision | true | Getaran (magnitude - baseline) |
| caption | text | true | Keterangan/catatan foto |
| photo_type | text | false | Tipe foto (default `manual`) |
| taken_at | timestamptz | false | Waktu pengambilan foto |
| created_at | timestamptz | false | Waktu data tersimpan di server |

### Batching & Interval Sampling
Raw readings (accelerometer, GPS) are generated at high frequencies in the UI. For trip recording, they are sampled at a dedicated 1-second interval before being saved as a combined `RoadReading` to an in-memory buffer. These buffered readings and events are then batched and uploaded to Supabase every 5 seconds. This drastically minimizes network overhead and API calls.

### Map Coordinate Derivation
The Map Visualization exclusively queries `road_readings` and `road_events` from Supabase:
- **Route Polyline**: Drawn using the sequenced `latitude` and `longitude` fields from `road_readings`.
- **Event Markers**: Plotted using the `latitude` and `longitude` fields from `road_events`. Missing or invalid coordinates (`null`, out-of-bounds) are safely discarded during rendering.

## Row Level Security (RLS) Policies
- Enabled on `profiles`, `road_sessions`, `road_readings`, `road_events`, and `ai_reports`.
- Enforces strict isolation: `auth.uid() = user_id`.
- For `profiles`, users can only read/update their own profile via `auth.uid() = id`.
- Service role keys are explicitly banned in the Flutter app to maintain security integrity.
