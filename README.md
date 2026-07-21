# RoadSense

## Developer
1. Raflian Taofiq Z.M (24.01.53.0008)
2. Rafif Nararya (24.01.53.0009)

Universitas Stikubank Semarang<br>
Program Studi Teknik Informatika

## Deskripsi Singkat
RoadSense adalah aplikasi mobile berbasis Flutter yang dirancang untuk memantau kondisi jalan menggunakan sensor GPS dan accelerometer pada smartphone. Aplikasi ini merekam perjalanan, menghitung jarak dan kecepatan, membaca getaran jalan, mendeteksi potensi anomali seperti jalan rusak atau lubang, lalu menyimpan data pengujian ke Supabase.

RoadSense dibuat untuk mendukung pengujian lapangan, dokumentasi kondisi infrastruktur, visualisasi rute, serta pembuatan laporan kondisi jalan secara lebih praktis dan terstruktur.

## Latar Belakang
Pemantauan kondisi jalan secara manual membutuhkan waktu, tenaga, dan peralatan khusus. Dengan memanfaatkan sensor yang tersedia pada smartphone, RoadSense menawarkan pendekatan yang lebih ringan untuk mengumpulkan data jalan secara real-time. Data GPS, kecepatan, getaran, foto bukti, dan laporan dapat digunakan sebagai bahan analisis akademik, dokumentasi pengujian, atau referensi awal untuk kebutuhan smart city.

## Tujuan Aplikasi
- Memantau getaran jalan secara real-time.
- Mengukur jarak, kecepatan, dan progress segmen saat pengujian.
- Mengumpulkan data jalan yang sudah memiliki koordinat GPS.
- Mendeteksi potensi jalan rusak berdasarkan threshold getaran.
- Menyimpan riwayat perjalanan, readings, events, dan foto bukti ke Supabase.
- Menampilkan riwayat perjalanan, detail pengujian, visualisasi peta, dan laporan PDF.
- Membantu proses pengujian jalan untuk kebutuhan akademik, validasi lapangan, dan dokumentasi kondisi infrastruktur.

## Fitur Utama
- **Authentication**: Login, registrasi, session management, dan Google Auth melalui Supabase.
- **Dashboard/Home**: Ringkasan status sistem, status cloud, mode utama, dan shortcut ke fitur inti.
- **Live Tracking Preview**: Mode pratinjau sensor untuk mengecek GPS, akurasi lokasi, speed, movement, accelerometer, dan kesiapan recording.
- **Sensitivity Mode**: Mode pengujian **Jalan Kaki**, **Motor Pelan**, dan **Mobil** agar filter GPS/movement lebih cocok dengan skenario lapangan.
- **Realtime GPS Metrics**: Menampilkan koordinat, akurasi GPS, kecepatan, jarak, movement, waktu update GPS, dan progress segmen.
- **Live Accelerometer Tracking**: Pemantauan getaran sumbu x, y, z, magnitude, vibration score, dan grafik sensor secara real-time.
- **Recording Readiness Checklist**: Validasi autentikasi, GPS, akurasi GPS, dan sensor sebelum perekaman cloud dimulai.
- **Cloud Trip Recording**: Membuat sesi perjalanan, menyimpan reading sensor, menghitung summary, dan menyinkronkan data ke Supabase.
- **In-Memory Batch Upload**: Upload data sensor dilakukan bertahap untuk mengurangi beban jaringan dan menjaga UI tetap responsif.
- **Pothole Detection Engine**: Mendeteksi potensi jalan rusak berdasarkan kombinasi vibration, speed, GPS accuracy, dan cooldown event.
- **Trip History**: Menampilkan daftar riwayat perjalanan pengguna, durasi, jarak, speed rata-rata, vibration, jumlah event, dan status sinkronisasi.
- **Trip Detail**: Menampilkan ringkasan sesi, grafik vibration history, tabel analisis segmen berdasarkan jarak, detected events, foto, dan laporan.
- **Map Visualization**: Menampilkan rute dan titik event/anomali pada peta interaktif menggunakan `flutter_map`.
- **Road Photo Evidence**: Mengambil foto bukti jalan saat recording aktif dan menyimpan metadata lokasi/sensor.
- **AI Scientific Report**: Membuat laporan kondisi jalan otomatis berbasis AI untuk kebutuhan dokumentasi teknis.
- **PDF Report Export**: Mengekspor laporan dan dokumentasi foto ke PDF profesional secara lokal.
- **Delete History**: Menghapus riwayat sesi perjalanan yang tidak dibutuhkan.

## Flow Program RoadSense
1. Pengguna membuka aplikasi RoadSense.
2. Pengguna login menggunakan email/password atau Google Auth.
3. Setelah login, aplikasi menampilkan dashboard berisi status sistem, status cloud, dan shortcut fitur.
4. Pengguna memilih **Live Tracking** untuk memulai pengujian jalan.
5. Pengguna memilih mode sensitivitas sesuai kondisi pengujian: **Jalan Kaki**, **Motor Pelan**, atau **Mobil**.
6. Pengguna menekan **Start Preview** untuk membaca GPS dan accelerometer tanpa menyimpan data ke cloud.
7. Aplikasi menampilkan data real-time berupa lokasi, akurasi GPS, speed, movement, jarak, progress segmen, dan grafik getaran.
8. Sistem menjalankan **Recording Readiness Checklist** agar recording hanya dimulai ketika autentikasi dan sensor sudah valid.
9. Pengguna menekan **Start Recording** untuk membuat `road_session` di Supabase.
10. Selama recording aktif, aplikasi menyimpan `road_readings`, menghitung jarak/kecepatan, memperbarui progress segmen, dan mengevaluasi potensi event jalan rusak.
11. Jika vibration melewati threshold dan syarat GPS/speed terpenuhi, sistem membuat `road_events`.
12. Pengguna dapat mengambil foto bukti jalan yang tersimpan sebagai `road_photos`.
13. Pengguna menekan **Stop Recording** untuk menyelesaikan sesi dan menyimpan summary perjalanan.
14. Pengguna membuka **Trip History** untuk melihat daftar sesi yang sudah direkam.
15. Pengguna membuka **Trip Detail** untuk melihat grafik, tabel analisis segmen, event, foto, peta, dan laporan.
16. Pengguna dapat membuat AI report dan mengekspor laporan ke PDF.

## Sensor yang Digunakan
- **Accelerometer / User Accelerometer**: Mendeteksi percepatan dan getaran perangkat pada sumbu x, y, dan z.
- **GPS Location**: Menentukan koordinat latitude dan longitude selama perjalanan.
- **GPS Speed**: Mengukur kecepatan pengguna/kendaraan dan membantu mengurangi false positive saat perangkat diam.
- **GPS Accuracy**: Memastikan data lokasi cukup layak untuk disimpan dan dianalisis.

## Arsitektur Sistem
RoadSense menggunakan **Supabase-only architecture** atau **Direct-to-Cloud**. SQLite tidak digunakan sebagai database utama, sehingga data pengujian langsung diarahkan ke Supabase.

**Alur arsitektur:**

```text
Flutter App
-> Sensor Services
-> Recording Validator
-> TripRecorderService
-> In-memory Buffer
-> Supabase APIs
-> Supabase PostgreSQL
```

## Alur Data
1. **Input Sensor**: GPS dan accelerometer membaca posisi, speed, akurasi, dan getaran perangkat.
2. **Filtering**: Data disaring berdasarkan mode sensitivitas, akurasi GPS, movement, dan batas noise.
3. **Realtime State**: UI Live Tracking memperbarui speed, distance, movement, segment progress, dan vibration chart.
4. **Recording Validator**: Sistem memastikan user login, GPS tersedia, akurasi GPS layak, dan sensor aktif.
5. **Session Start**: Saat recording dimulai, aplikasi membuat `road_session` baru di Supabase.
6. **Reading Capture**: Aplikasi mengubah data sensor menjadi `road_readings` periodik.
7. **Batch Upload**: Reading dikirim ke Supabase dalam batch agar koneksi lebih efisien.
8. **Event Detection**: Vibration yang melewati rule akan dicatat sebagai `road_events` jika speed dan GPS valid.
9. **Photo Evidence**: Foto jalan dapat dilampirkan ke sesi dan disimpan sebagai `road_photos`.
10. **Session Summary**: Saat recording berhenti, aplikasi menghitung durasi, jarak, speed, max vibration, total readings, dan total events.
11. **History and Reports**: Data sesi ditampilkan di Trip History/Trip Detail, divisualisasikan di peta, dibuat AI report, dan diekspor PDF.

## Database Supabase
Aplikasi ini menggunakan PostgreSQL pada Supabase dengan tabel utama berikut:
- **`profiles`**: Menyimpan metadata pengguna yang terhubung dengan `auth.users`.
- **`road_sessions`**: Menyimpan data sesi perjalanan, waktu mulai/selesai, jarak, durasi, dan summary.
- **`road_readings`**: Menyimpan sampel pembacaan GPS, speed, vibration, dan accelerometer selama perjalanan.
- **`road_events`**: Menyimpan deteksi anomali atau potensi lubang saat threshold terpenuhi.
- **`road_photos`**: Menyimpan metadata foto dokumentasi yang merujuk ke file pada Supabase Storage bucket `road-photos`.

## Row Level Security (RLS)
Supabase di RoadSense diamankan dengan aturan **Row Level Security**:
- Pengguna hanya dapat membaca dan mengubah data `profiles` miliknya sendiri.
- Pengguna hanya dapat mengakses `road_sessions`, `road_readings`, `road_events`, dan `road_photos` miliknya sendiri.
- Aplikasi Flutter hanya boleh menggunakan anon/public key dan token sesi pengguna.
- `service_role` key tidak boleh disimpan di source code Flutter karena dapat membahayakan seluruh data project.

## Pothole Detection Rules
Kriteria mesin deteksi jalan rusak:
- **damaged_road**: vibration >= 3.0 dan < 5.0
- **pothole**: vibration >= 5.0 dan < 8.0
- **severe_pothole**: vibration >= 8.0
- Kecepatan kendaraan harus >= 5.0 km/h.
- Akurasi GPS harus <= 25 meter.
- Cooldown event digunakan untuk mencegah pencatatan ganda pada lubang yang sama.

## Recording Readiness
Sistem akan memblokir fitur mulai perekaman apabila kriteria berikut belum terpenuhi:
- Pengguna sudah login.
- Data accelerometer tersedia.
- Data GPS tersedia.
- Akurasi GPS dapat diterima.
- Koneksi cloud dan konfigurasi Supabase tersedia.

## Teknologi yang Digunakan
- **Flutter** dan **Dart**: Framework utama untuk membangun aplikasi mobile RoadSense.
- **Material 3**: Dasar komponen UI, warna, typography, button, card, dan navigation style.
- **Supabase Flutter**: Integrasi aplikasi Flutter dengan Supabase.
- **Supabase Auth**: Login email/password, session management, dan OAuth Google.
- **Supabase PostgreSQL**: Database relasional untuk menyimpan profil, sesi perjalanan, readings, events, dan foto.
- **Supabase Row Level Security (RLS)**: Proteksi data agar setiap user hanya mengakses data miliknya sendiri.
- **Supabase Storage**: Penyimpanan bukti foto jalan pada bucket `road-photos`.
- **Google OAuth**: Provider login Google yang diaktifkan melalui Supabase.
- **AI API**: Pembuatan AI Scientific Report berdasarkan ringkasan data perjalanan.
- **`sensors_plus`**: Akses data accelerometer perangkat.
- **`geolocator`**: Akses GPS, koordinat, akurasi, dan speed.
- **`permission_handler`**: Manajemen izin lokasi, kamera, dan akses perangkat.
- **`fl_chart`**: Grafik vibration history dan data sensor.
- **`flutter_map`** dan **`latlong2`**: Visualisasi rute dan marker pada peta.
- **`intl`**: Formatting tanggal, waktu, angka, durasi, dan tampilan lokal.
- **`uuid`**: Pembuatan ID unik untuk data lokal/sesi.
- **`image_picker`** dan **`image`**: Pengambilan serta pemrosesan foto dokumentasi.
- **`pdf`**, **`printing`**, **`path_provider`**, dan **`share_plus`**: Pembuatan, preview, penyimpanan, dan share laporan PDF.
- **`http`** dan **`flutter_markdown`**: Integrasi API laporan dan rendering konten laporan.
- **Gradle / Android Build Tools**: Build APK/AAB untuk distribusi Android.

## Design System
RoadSense menggunakan pendekatan desain **scientific road monitoring** yang ringan, modern, dan responsif. Referensi visual diselaraskan dengan karakter huashu-design di folder `tools/huashu-design`, tetapi tetap dibuat hemat komputasi agar performa Live Tracking stabil.

- **Visual Identity**: Tema monitoring sensor, jaringan, GPS, dan data jalan dengan kesan akademik-profesional.
- **Color Palette**: Deep teal/navy sebagai warna utama, soft sand/off-white sebagai background, terracotta sebagai accent/warning, hijau sebagai status sukses, dan abu netral untuk informasi sekunder.
- **Typography**: Judul dibuat tebal dan jelas, teks deskripsi dibuat ringan, dan angka metrik dibuat kontras agar mudah dibaca saat pengujian lapangan.
- **Cards and Surfaces**: Konten utama memakai card besar dengan radius lembut, shadow ringan, dan spacing konsisten agar tidak terlihat seperti template datar.
- **Metric Components**: Data GPS, speed, distance, segment, vibration, dan status ditampilkan dalam tile ringkas agar mudah dipantau di layar kecil.
- **Responsive Layout**: Layout disusun mobile-first, menggunakan SafeArea, padding bawah tambahan untuk navigation bar Android, dan komponen yang tidak bergantung pada ukuran layar tetap.
- **State Feedback**: Status recording, preview, loading, error, readiness checklist, dan empty state ditampilkan dengan warna serta label yang jelas.
- **Performance Principle**: UI Live Tracking menghindari animasi berat, menjaga chart tetap ringan, dan mengutamakan update data yang stabil daripada efek visual berlebihan.

## Struktur Folder
```text
lib/
|-- core/                # Utilitas inti, konfigurasi, theme, logger, helper waktu
|-- data/
|   |-- models/          # Model data dan JSON serialization
|   `-- remote/          # Integrasi API Supabase
|-- features/
|   |-- auth/            # Halaman login, register, dan Google Auth
|   |-- dashboard/       # Halaman beranda utama
|   |-- history/         # Halaman riwayat cloud
|   |-- live_tracking/   # Preview sensor, recording, GPS metrics, dan chart live
|   |-- map/             # Visualisasi peta
|   `-- trip_detail/     # Detail sesi, events, foto, laporan, dan PDF
|-- services/            # LocationService, TripRecorderService, dan logika bisnis
`-- shared/              # Widget reusable dan komponen UI bersama

assets/branding/         # Logo dan aset branding RoadSense
docs/                    # Dokumentasi proyek tambahan
supabase/migrations/     # Skema database dan trigger PostgreSQL
tools/                   # Script build, generator aset, dan referensi huashu-design
```

## Cara Menjalankan Project
1. **Install dependencies**

   ```bash
   flutter pub get
   ```

2. **Setup Supabase**

   Buat proyek di [Supabase](https://supabase.com), lalu jalankan file SQL pada folder `supabase/migrations/` melalui SQL Editor Supabase.

3. **Jalankan aplikasi**

   Gunakan environment variables agar credential tidak ditulis langsung di source code.

   ```bash
   flutter run --dart-define=SUPABASE_URL=your-url --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

   Untuk menjalankan pada device Android fisik:

   ```bash
   flutter devices
   flutter run -d DEVICE_ID --dart-define=SUPABASE_URL=your-url --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

4. **Build Android release**

   Untuk APK/AAB publik, pastikan nilai Supabase ikut dibawa saat build. Cara paling aman di Windows adalah mengisi file `.env` lokal yang sudah di-ignore git, lalu jalankan:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\build_android_release.ps1
   ```

   Opsi target:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\build_android_release.ps1 -Target apk
   powershell -ExecutionPolicy Bypass -File .\tools\build_android_release.ps1 -Target appbundle
   ```

## Environment Variables
- `SUPABASE_URL`: Endpoint REST URL proyek Supabase.
- `SUPABASE_ANON_KEY`: Kunci anonim/public dari proyek Supabase.

Gunakan `--dart-define` atau `.env` lokal yang sudah di-ignore git untuk konfigurasi rahasia. Jangan commit credential ke GitHub.

## Setup Google Auth
RoadSense mendukung login Google melalui Supabase OAuth tanpa paket auth tambahan yang berat.

1. Di dashboard Supabase, buka **Authentication > Providers > Google**, lalu aktifkan provider Google.
2. Masukkan **Client ID** dan **Client Secret** dari Google Cloud Console ke konfigurasi provider Supabase.
3. Tambahkan callback aplikasi mobile ke **Authentication > URL Configuration > Redirect URLs**:

   ```text
   id.roadsense.app://login-callback
   ```

4. Di Google Cloud Console, pastikan redirect URL Supabase OAuth juga terdaftar pada OAuth Client.
5. Setelah konfigurasi benar, tombol **Lanjut dengan Google** akan membuka browser lalu kembali otomatis ke aplikasi.

## Testing
Untuk memverifikasi stabilitas project:

```bash
flutter analyze
flutter test
```

Pengujian sensor nyata harus dilakukan menggunakan physical Android device. Sensor pada web atau emulator tidak dapat menghasilkan data getaran jalan secara valid.

## Catatan Pengujian Android
- Aktifkan **Developer Options** pada perangkat Android.
- Aktifkan **USB Debugging** atau **Wireless Debugging**.
- Saat prompt muncul di Android, izinkan autorisasi komputer.
- Biarkan layar perangkat tetap menyala selama recording agar sistem operasi tidak membekukan proses sensor.
- Letakkan HP pada holder atau kompartemen kendaraan dengan stabil.
- Jangan mengoperasikan smartphone saat sedang mengemudi.

## Keterbatasan Saat Ini
- Aplikasi membutuhkan koneksi internet aktif karena arsitektur utama adalah Direct-to-Cloud.
- Tidak tersedia perekaman offline berkesinambungan.
- Web dan emulator tidak dapat memvalidasi getaran jalan nyata secara akurat.
- Nilai threshold sensor masih membutuhkan kalibrasi lapangan berdasarkan jenis kendaraan, posisi HP, dan kondisi jalan.
- Akurasi GPS tetap dipengaruhi perangkat, cuaca, area tertutup, gedung tinggi, dan kualitas sinyal.

## Roadmap
- [x] Supabase-only recording.
- [x] Android sensor validation.
- [x] Cloud readings batch upload.
- [x] Pothole detection engine.
- [x] Map visualization.
- [x] AI Scientific Report.
- [x] Road Photo Evidence dan PDF Export.
- [x] Google Auth.
- [x] Sensitivity mode untuk skenario jalan kaki, motor pelan, dan mobil.
- [ ] Marker clustering untuk event jalan.
- [ ] Dashboard admin berbasis web.
- [ ] Export raw data ke CSV.
- [ ] Mode kalibrasi otomatis berdasarkan posisi HP dan jenis kendaraan.
- [ ] Offline sync pada versi mendatang.

## Troubleshooting
- **Android NDK Issue**: Jika build gagal karena NDK, perbarui versi NDK di Android Studio SDK Manager, lalu jalankan `flutter clean`.
- **USB Device Unauthorized**: Cabut kabel USB, hapus authorization dari pengaturan Android, sambungkan ulang, lalu terima notifikasi di HP.
- **Supabase Key Missing**: Pastikan command `flutter run` atau build release memakai `--dart-define` atau `.env` yang benar.
- **Google Login Unsupported Provider**: Aktifkan Google provider di Supabase dan isi Client ID serta Client Secret.
- **Google Login Redirect ke localhost**: Ubah Site URL dan Redirect URLs di Supabase agar memakai deep link aplikasi, bukan `localhost:3000`.
- **Start Recording Disabled**: Pastikan indikator readiness sudah valid dan akurasi GPS cukup baik.
- **GPS Distance Tidak Bertambah**: Coba area terbuka, pilih sensitivity mode yang sesuai, pastikan permission location diberikan, dan gunakan physical device.
- **road_events Tidak Terbuat**: Event hanya tercatat jika vibration, speed, GPS accuracy, dan cooldown memenuhi aturan.

## Status Project
**Status: Minimum Viable Product (MVP) Cloud-Only**

- Auth: Completed
- Google Auth: Completed
- Supabase-only recording: Completed
- Android sensor validation: Completed
- Cloud readings batch upload: Completed
- Pothole detection engine: Completed
- Map visualization: Completed
- AI Scientific Report: Completed
- Road Photo Evidence and PDF Export: Completed
- UI/UX responsive refinement: Ongoing
