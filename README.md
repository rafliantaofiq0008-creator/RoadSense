# RoadSense

## Deskripsi Singkat
RoadSense adalah aplikasi mobile berbasis Flutter yang dirancang untuk mendeteksi getaran jalan dan potensi lubang (potholes) menggunakan sensor accelerometer dan GPS bawaan pada smartphone pengguna. Aplikasi ini ditujukan untuk memetakan kualitas infrastruktur jalan secara real-time berdasarkan data sensor pergerakan kendaraan.

## Latar Belakang
Pemantauan kondisi jalan seringkali membutuhkan peralatan khusus yang mahal dan survei manual yang memakan waktu. Dengan memanfaatkan sensor pada smartphone yang dimiliki oleh hampir setiap pengemudi, RoadSense menawarkan solusi pengumpulan data secara urun daya (crowdsourcing). Data getaran dan lokasi lubang ini sangat berguna untuk pemantauan kualitas jalan, pelaporan komunitas, serta pengumpulan data berkonsep *smart city* yang dapat membantu pemerintah atau instansi terkait dalam memprioritaskan perbaikan infrastruktur.

## Tujuan Aplikasi
- Memantau tingkat getaran jalan secara real-time.
- Mengumpulkan data jalan yang telah ditandai dengan koordinat GPS (GPS-tagged).
- Mendeteksi potensi lubang atau jalan rusak secara otomatis berdasarkan threshold getaran.
- Menyimpan data riwayat perjalanan dengan aman di Supabase.
- Menyediakan riwayat perjalanan berbasis cloud dan visualisasi peta (direncanakan pada rilis mendatang).

## Fitur Utama
- **Supabase Authentication**: Sistem login, registrasi, dan manajemen sesi yang aman.
- **Live Accelerometer Tracking**: Pemantauan getaran (sumbu x, y, z dan magnitude) secara real-time.
- **GPS Speed and Accuracy Tracking**: Pemantauan kecepatan kendaraan dan tingkat akurasi sinyal GPS.
- **Recording Readiness Checklist**: Validasi kelayakan sensor (GPS dan Accelerometer) sebelum perekaman diizinkan.
- **Cloud Trip Recording**: Perekaman sesi perjalanan yang langsung tersinkronisasi ke cloud.
- **In-Memory Batch Upload**: Proses upload data sensor dilakukan dalam batch setiap 5 detik untuk efisiensi jaringan, tanpa memberatkan memori perangkat.
- **Pothole Detection Engine**: Mesin deteksi lubang otomatis yang berjalan dengan evaluasi *threshold* dari raw sensor.
- **Cloud Trip History**: Menampilkan riwayat perjalanan pengguna dari cloud.
- **Cloud Trip Detail**: Melihat detail spesifik dari sebuah sesi perjalanan (statistik, jumlah getaran, dll).
- **Map Visualization**: Visualisasi data anomali di atas peta interaktif menggunakan flutter_map.
- **AI Scientific Report**: Generator laporan kondisi jalan otomatis berbasis AI (Google Gemini) yang ditujukan untuk Diskominfo atau Dinas PUPR.
- **Road Photo Evidence**: Pengambilan dan lampiran bukti foto dokumentasi jalan yang terintegrasi dengan laporan.
- **PDF Report Export**: Pembuatan laporan AI (termasuk galeri foto) dalam format dokumen PDF profesional secara lokal.
## Sensor yang Digunakan
- **User Accelerometer / Accelerometer**: Mendeteksi gaya percepatan pada perangkat tanpa memperhitungkan gravitasi bumi (mendeteksi guncangan suspensi mobil).
- **GPS**: Menentukan koordinat lokasi kejadian anomali jalan.
- **GPS Speed**: Mencegah false-positive (deteksi palsu) saat kendaraan sedang diam atau berjalan terlalu lambat.
- **GPS Accuracy**: Memastikan bahwa data lokasi yang direkam memiliki akurasi tinggi (biasanya di bawah 25 meter).

## Arsitektur Sistem
RoadSense menggunakan **Supabase-only architecture** (Direct-to-Cloud). SQLite telah sepenuhnya dihapus dari sistem ini.

**Alur Data Arsitektur:**
`Flutter App` → `Sensor Services` → `Recording Validator` → `TripRecorderService` → `In-memory Buffer` → `Supabase APIs` → `Supabase PostgreSQL`

## Alur Data
1. Pengguna login ke dalam aplikasi.
2. Pengguna memulai fitur **Start Preview** di halaman Live Tracking.
3. Aplikasi membaca aliran data dari accelerometer dan GPS.
4. **Readiness Checklist** memvalidasi ketersediaan data sensor, kecepatan, dan akurasi GPS.
5. Jika valid, pengguna menekan **Start Recording**.
6. Aplikasi membuat data `road_session` baru di tabel Supabase.
7. Aplikasi mengekstrak data sensor menjadi `road_readings` setiap 1 detik.
8. Aplikasi mengunggah *readings* tersebut dalam format batch setiap 5 detik.
9. Saat deteksi getaran melampaui batas (rules terpenuhi), aplikasi mencatat `road_events` (misal: pothole).
10. Pengguna menekan **Stop Recording**.
11. Aplikasi melakukan pembaruan summary sesi perjalanan (rata-rata kecepatan, total deteksi) di Supabase.

## Database Supabase
Aplikasi ini menggunakan database PostgreSQL pada Supabase dengan tabel utama sebagai berikut:
- **`profiles`**: Menyimpan metadata pengguna (seperti nama lengkap) yang terhubung otomatis melalui *trigger* ke tabel `auth.users`.
- **`road_sessions`**: Menyimpan data sesi perjalanan (waktu mulai, waktu selesai, ringkasan jarak/kecepatan).
- **`road_readings`**: Menyimpan sampel pembacaan kombinasi getaran dan kecepatan per detik selama perjalanan.
- **`road_events`**: Menyimpan deteksi anomali/lubang saat batas threshold getaran terlampaui.
- **`road_photos`**: Menyimpan metadata foto dokumentasi (disertai koordinat GPS dan data sensor) yang merujuk ke file gambar pada Supabase Storage (`road-photos` bucket).

## Row Level Security (RLS)
Supabase di RoadSense diamankan dengan aturan **Row Level Security**:
- Pengguna hanya dapat membaca dan mengubah data pada tabel `profiles` miliknya sendiri.
- Pengguna hanya dapat mengakses `road_sessions`, `road_readings`, dan `road_events` miliknya sendiri (berdasarkan UUID `user_id`).
- **Penting:** Aplikasi *front-end* Flutter ini murni menggunakan Anonymous Key dan token sesi pengguna. `service_role` key dilarang keras disertakan dalam *source code* Flutter demi keamanan.

## Pothole Detection Rules
Kriteria mesin deteksi jalan rusak:
- **damaged_road**: *vibration* $\ge$ 3.0 dan $<$ 5.0
- **pothole**: *vibration* $\ge$ 5.0 dan $<$ 8.0
- **severe_pothole**: *vibration* $\ge$ 8.0
- Kecepatan kendaraan harus $\ge$ 5.0 km/h.
- Akurasi GPS harus $\le$ 25 meter.
- **Cooldown**: Berlaku waktu jeda selama 3 detik antara satu deteksi dengan deteksi selanjutnya untuk mencegah rentetan notifikasi ganda pada lubang yang sama.

## Recording Readiness
Sistem akan memblokir fitur mulai perekaman apabila kriteria berikut belum terpenuhi (ditandai dengan checklist di UI):
- Pengguna sudah terautentikasi (login).
- Data Accelerometer tersedia di perangkat.
- Data GPS tersedia.
- Akurasi GPS dapat diterima ($\le$ 25 meter).

## Teknologi yang Digunakan
- **Flutter** & **Dart** (Mobile UI Framework)
- **Supabase** (Backend as a Service)
- **Supabase Auth** (Autentikasi Pengguna)
- **Supabase PostgreSQL & RLS** (Database Relasional dan Keamanan)
- `sensors_plus` (Akses accelerometer)
- `geolocator` (Akses lokasi GPS presisi tinggi)
- `permission_handler` (Manajemen hak akses Android/iOS)
- `fl_chart` (Visualisasi data chart)
- `flutter_map` (Direncanakan untuk peta interaktif)
- `uuid` (Generasi ID unik)
- `intl` (Formatting tanggal dan angka)
- `image_picker`, `image` (Akses kamera dan kompresi foto)
- `pdf`, `printing`, `path_provider`, `share_plus` (Ekspor dokumen PDF dan layanan share)

## Struktur Folder
```text
lib/
├── core/                # Utilitas inti (konstanta, kalkulator, timer)
├── data/
│   ├── models/          # Model data (JSON serialization)
│   └── remote/          # Integrasi API Supabase
├── features/
│   ├── auth/            # Halaman Login dan Register
│   ├── dashboard/       # Halaman beranda utama
│   ├── history/         # Halaman riwayat cloud
│   ├── live_tracking/   # Perekaman data dan chart sensor live
│   ├── map/             # Visualisasi peta (direncanakan)
│   └── trip_detail/     # Halaman detail sebuah sesi
└── services/            # Layanan logika bisnis (LocationService, TripRecorderService, dll)
docs/                    # Dokumentasi proyek tambahan
supabase/migrations/     # Skema database dan trigger PostgreSQL
```

## Cara Menjalankan Project

1. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Setup Supabase:**
   - Buat proyek di [Supabase](https://supabase.com).
   - Eksekusi file SQL yang berada di dalam folder `supabase/migrations/` pada SQL Editor di dashboard Supabase Anda.

3. **Jalankan Aplikasi:**
   Jalankan project dengan melampirkan environment variables. Jangan pernah memasukkan `SUPABASE_URL` atau `SUPABASE_ANON_KEY` ke dalam source code.

   ```bash
   flutter run --dart-define=SUPABASE_URL=your-url --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```
   
   Untuk menjalankan pada spesifik device fisik Android:
   ```bash
   flutter devices
   flutter run -d DEVICE_ID --dart-define=SUPABASE_URL=your-url --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

## Environment Variables
- `SUPABASE_URL`: Endpoint REST URL proyek Supabase Anda.
- `SUPABASE_ANON_KEY`: Kunci anonim (public) dari proyek Supabase Anda.
*(Gunakan fitur `--dart-define` atau `.env` lokal yang sudah di-ignore git untuk konfigurasi rahasia).*

## Testing
Untuk memverifikasi stabilitas arsitektur, jalankan:
```bash
flutter analyze
flutter test
```
**Perhatian:** Pengujian sensor nyata harus dilakukan menggunakan *Physical Android Device*. Sensor pada mode web atau emulator tidak dapat menghasilkan gaya akselerasi getaran kendaraan di jalan raya secara valid.

## Catatan Pengujian Android
- Aktifkan **Developer Options** pada perangkat Android Anda.
- Aktifkan **USB Debugging** (atau Wireless Debugging).
- Saat *prompt* muncul di layar Android, izinkan autorisasi komputer.
- **Biarkan layar perangkat tetap menyala (Screen On)** selama perekaman perjalanan, sebab sistem operasi Android dapat membekukan *timer* aplikasi saat layar mati.
- Letakkan HP di kompartemen mobil atau holder dengan stabil.
- *Jangan pernah mengoperasikan smartphone saat Anda sedang mengemudi!*

## Keterbatasan Saat Ini
- Aplikasi ini membutuhkan koneksi internet aktif (Direct-to-Cloud) karena database SQLite offline telah dihapus sepenuhnya dari arsitektur.
- Tidak tersedia perekaman offline berkesinambungan. Jika internet terputus, buffer in-memory bisa hilang jika aplikasi ditutup sebelum sinkronisasi batch berjalan kembali.
- Flutter Web dan Emulator tidak dapat memvalidasi data getaran di jalan nyata secara akurat.
- Visualisasi peta jalan rusak masih dalam tahap pengerjaan (direncanakan di iterasi berikutnya).
- Nilai threshold sensor (3.0, 5.0, 8.0) saat ini membutuhkan kalibrasi lapangan lebih lanjut yang spesifik terhadap variasi berat kendaraan.

## Roadmap
- [ ] Peningkatan stabilitas sampling background.
- [x] Implementasi Map Visualization (`flutter_map`).
- [ ] Marker clustering untuk lubang jalan.
- [x] AI Road Damage Scientific Report (Diskominfo).
- [x] Ekspor data Laporan ke PDF (disertai lampiran foto).
- [ ] Halaman Admin / Dashboard Pelaporan berbasis Web.
- [ ] Ekspor data raw ke CSV.
- [ ] Mode Kalibrasi (Kalibrasi berat dan posisi HP otomatis).
- [ ] Simulation Mode untuk developer tanpa fisik device.
- [ ] Opsi Offline Sync di masa mendatang jika skala data membesar.

## Troubleshooting
- **Android NDK Issue**: Jika *build* gagal karena NDK, perbarui versi NDK di Android Studio SDK Manager, lalu jalankan `flutter clean`.
- **USB Device Unauthorized**: Cabut kabel USB, cabut hak *Authorization* dari pengaturan Android, sambungkan ulang, lalu terima notifikasi di HP.
- **Supabase Key Missing**: Pastikan Anda telah memasukkan perintah `--dart-define` saat menekan *Run*.
- **Start Recording Disabled**: Pastikan indikator "Recording Readiness" hijau semua. Jika GPS Accuracy merah, bergeraklah ke tempat terbuka di bawah langit.
- **road_events tidak terbuat**: Walaupun grafik *vibration* melonjak tajam, jika *speed* tidak melampaui 5 km/h, *events* tidak akan direkam sesuai aturan desain (untuk mencegah false positive saat mobil berhenti).

## Status Project
**Status: Minimum Viable Product (MVP) Cloud-Only**
- Auth: ✅ Completed
- Supabase-only recording: ✅ Completed
- Android sensor validation: ✅ Completed
- Cloud readings batch upload: ✅ Completed
- Pothole detection engine: ✅ Completed
- Map visualization: ✅ Completed
- AI Scientific Report: ✅ Completed
- Road Photo Evidence & PDF Export: ✅ Completed

## Author
**Raflian Taofiq Z.M**  
Universitas Stikubank Semarang  
Teknik Informatika
