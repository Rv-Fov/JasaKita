# JasaKita

> Marketplace jasa + manajemen pekerjaan dalam satu aplikasi Flutter.
> *Menghubungkan jasa. Merapikan pekerjaan.*

JasaKita adalah aplikasi untuk memesan jasa sehari-hari seperti buruh tani, tukang bangunan, kuli angkut, dan servis elektronik, dengan cara kerja mirip aplikasi ojek online. Bedanya, aplikasi ini juga **mengelola pekerjaannya**: jadwal mitra, progres pekerjaan, sampai bukti foto penyelesaian.

Proyek ini adalah MVP untuk tugas mata kuliah Pemrograman Bergerak (Kelompok 4, Kelas A).

> **Nama aplikasi:** "JasaKita" masih nama sementara. Ubah lewat konstanta `appName` di `lib/main.dart`.

---

## Latar belakang

Banyak jasa yang dibutuhkan masyarakat masih dipesan secara konvensional: harus mencari kontak dulu lewat telepon atau tanya tetangga, dan belum tentu orangnya siap. Di sisi lain, pelaku jasa sulit menjangkau pelanggan baru.

Masalahnya bukan yang paling mendesak, tetapi **kemudahan**. Pelanggan perlu cara mudah mengakses jasa, dan mitra perlu cara meningkatkan jangkauan.

Untuk jasa berdurasi panjang (tukang bangunan, buruh tani), aplikasi menyediakan manajemen pekerjaan: kalender ketersediaan, milestone, dan laporan progres, sehingga pelanggan bisa memantau mana mitra yang siap dan sampai mana pekerjaannya.

---

## Fitur

### Untuk pelanggan
- **Cari jasa** berdasarkan kata kunci dan kategori (Pertanian, Bangunan, Angkut, Servis Elektronik, Lainnya).
- **Filter "tersedia hari ini"** supaya hanya mitra yang siap yang tampil.
- **Mitra terdekat:** daftar diurutkan dari jarak lokasi pelanggan, lengkap dengan badge, rating, dan tarif.
- **Profil mitra** dengan kalender ketersediaan (tersedia / terjadwal / tidak tersedia) dan ulasan.
- **Pesan jasa** dengan memilih tanggal mulai, durasi (hari), lokasi, catatan kebutuhan, dan metode pembayaran (digital / tunai).
- **Pilih lokasi seperti di aplikasi peta:** tombol GPS, cari alamat, atau geser peta dengan pin di tengah.
- **Cegah bentrok jadwal:** pesanan ditolak otomatis bila mitra libur atau sudah terjadwal di tanggal itu.
- **Pantau pesanan:** status bertahap, progress bar pekerjaan, timeline milestone, dan laporan foto dari mitra.
- **Konfirmasi selesai + ulasan:** pelanggan menutup pesanan dan memberi rating setelah melihat bukti.
- **Catatan revisi kesepakatan** untuk perubahan jadwal atau harga yang disepakati kedua pihak.

### Untuk mitra
- **Terima / tolak permintaan**, dengan peringatan bila bentrok dengan jadwal atau liburnya.
- **Kalender ketersediaan:** ketuk tanggal untuk menandai libur atau membuka jadwal. Tanggal yang sudah terjadwal tidak bisa diubah.
- **Milestone & tugas otomatis** saat pesanan diterima; mitra bisa menambah tugas dan mengubah statusnya.
- **Lapor progres dengan foto** (opsional) selama pekerjaan berjalan.
- **Bukti penyelesaian wajib:** tombol "Selesaikan" hanya bisa dipakai bila semua tugas selesai dan ada minimal satu foto bukti.
- **Performa mitra:** jumlah pekerjaan selesai, rating, ulasan, dan badge (Mitra Baru / Aktif / Terpercaya).

### Alur pesanan

```
Diajukan -> Dikonfirmasi -> Berjalan -> Menunggu konfirmasi -> Selesai
    |             |
 Ditolak      Dibatalkan
```

Jadwal mitra baru **terkunci** setelah pesanan diterima, sehingga tidak terjadi double booking.

---

## Teknologi

| Kebutuhan | Yang dipakai |
|---|---|
| Framework | Flutter (Material 3), Dart 3 |
| Peta | [`flutter_map`](https://pub.dev/packages/flutter_map) + tile OpenStreetMap |
| GPS | [`geolocator`](https://pub.dev/packages/geolocator) |
| Cari alamat | Nominatim (OpenStreetMap) via [`http`](https://pub.dev/packages/http) |
| Foto | [`image_picker`](https://pub.dev/packages/image_picker) |
| State | `ChangeNotifier` bawaan Flutter (tanpa package tambahan) |

Peta tidak memerlukan API key.

---

## Menjalankan proyek

### Prasyarat
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (cek dengan `flutter doctor`)
- VS Code dengan ekstensi **Flutter** dan **Dart** (atau Android Studio)
- Pengguna Windows: aktifkan **Developer Mode** (Settings → For developers), karena plugin Flutter memerlukan dukungan symlink.

### Langkah

```bash
# 1. Ambil kode
git clone <url-repo-kamu>
cd jasakita

# 2. Pasang dependensi
flutter pub get

# 3. Jalankan (pilih device: emulator Android, HP, atau Chrome)
flutter run
```

Jika folder platform (`android/`, `web/`, dll.) belum ada, buat dulu di dalam folder proyek:

```bash
flutter create .
```

### Izin Android
Tambahkan di `android/app/src/main/AndroidManifest.xml`, di dalam `<manifest>` dan sebelum `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### Izin iOS (bila dipakai)
Tambahkan di `ios/Runner/Info.plist`: `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, dan `NSPhotoLibraryUsageDescription`.

### Menjalankan di Chrome
Tidak perlu konfigurasi tambahan. Browser akan meminta izin lokasi dan kamera. Perlu diketahui, GPS di laptop biasanya kurang akurat, dan tombol kamera di web umumnya hanya membuka pemilih file.

---

## Struktur kode

```
lib/
├── main.dart          # Titik masuk, pemilih peran (Pelanggan / Mitra)
├── models.dart        # Model data + helper tanggal, rupiah, jarak
├── store.dart         # State aplikasi + aturan bisnis (bentrok jadwal, status, rating)
├── ui.dart            # Tema dan komponen UI bersama
├── shared.dart        # Kalender ketersediaan, chip status, legenda
├── location.dart      # GPS, pencarian alamat, peta, layar pilih lokasi
├── media.dart         # Kamera/galeri, penampil foto, form laporan
├── customer.dart      # Alur pelanggan
├── partner.dart       # Alur mitra
└── order_detail.dart  # Detail pesanan, timeline, laporan foto, ulasan
```

Seluruh logika bisnis ada di `store.dart`. Saat backend dipilih, isi class ini bisa diganti dengan pemanggilan API tanpa banyak mengubah tampilan.

---

## Batasan versi saat ini (MVP)

- **Data hanya di memori**, tanpa backend, sehingga hilang saat aplikasi ditutup. Data contoh ada di `AppStore._seed()`.
- **Belum ada login**; pengguna memilih peran Pelanggan atau Mitra di layar awal (mode demo).
- **Foto belum tersimpan permanen** (belum ada penyimpanan cloud).
- **Pembayaran digital belum terintegrasi** payment gateway; metode hanya dicatat.
- Pencarian alamat memakai layanan gratis Nominatim dengan batas pemakaian wajar, cukup untuk demo, bukan untuk produksi.

## Rencana pengembangan

- [ ] Backend dan autentikasi (mis. Supabase / PostgreSQL)
- [ ] Penyimpanan foto bukti di cloud
- [ ] Integrasi payment gateway
- [ ] Chat negosiasi pelanggan-mitra
- [ ] Notifikasi (pesanan baru, perubahan status)
- [ ] Dashboard admin dan penanganan sengketa
- [ ] Proyek multi-tim (beberapa tim dalam satu pekerjaan)
- [ ] Pemilihan nama dan identitas visual final

---

## Atribusi

Peta dan data alamat © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, dilisensikan di bawah ODbL.

## Tim

Kelompok 4, Pemrograman Bergerak, Kelas A.

<!-- Tambahkan nama anggota dan screenshot aplikasi di sini -->
