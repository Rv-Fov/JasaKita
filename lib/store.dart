import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'models.dart';

/// State aplikasi (in-memory). Untuk fase lanjut, ganti isi class ini
/// dengan pemanggilan Supabase/PostgreSQL tanpa mengubah UI.
final store = AppStore();

class AppStore extends ChangeNotifier {
  AppStore() {
    _seed();
  }

  final String customerName = 'Budi Santoso';
  final String currentPartnerId = 'p2'; // akun mitra untuk demo

  final List<Partner> partners = [];
  final List<Booking> bookings = [];
  int _seq = 10;

  /// Lokasi pelanggan (dipilih lewat GPS / pencarian). Dipakai untuk jarak mitra.
  PickedLocation? myLocation;

  void setMyLocation(PickedLocation l) {
    myLocation = l;
    notifyListeners();
  }

  double? distanceTo(Partner p) {
    final l = myLocation;
    if (l == null) return null;
    return distanceMeters(l.lat, l.lng, p.lat, p.lng);
  }

  Partner partner(String id) => partners.firstWhere((p) => p.id == id);
  Booking booking(String id) => bookings.firstWhere((b) => b.id == id);

  // ---------- Ketersediaan ----------

  bool _locks(Booking b) =>
      b.status == BookingStatus.dikonfirmasi ||
      b.status == BookingStatus.berjalan ||
      b.status == BookingStatus.menungguKonfirmasi;

  SlotStatus slotStatus(String partnerId, DateTime d) {
    final booked = bookings.any(
      (b) => b.partnerId == partnerId && _locks(b) && b.covers(d),
    );
    if (booked) return SlotStatus.terjadwal;
    if (partner(partnerId).offDays.contains(dateKey(d))) {
      return SlotStatus.tidakTersedia;
    }
    return SlotStatus.tersedia;
  }

  /// Hari-hari yang bentrok (libur mitra / sudah terjadwal).
  List<DateTime> conflictDays(
    String partnerId,
    DateTime start,
    int days, {
    String? ignoreId,
  }) {
    final res = <DateTime>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final off = partner(partnerId).offDays.contains(dateKey(d));
      final booked = bookings.any(
        (b) =>
            b.id != ignoreId &&
            b.partnerId == partnerId &&
            _locks(b) &&
            b.covers(d),
      );
      if (off || booked) res.add(d);
    }
    return res;
  }

  String? toggleOff(String partnerId, DateTime d) {
    if (slotStatus(partnerId, d) == SlotStatus.terjadwal) {
      return 'Tanggal ini sudah terjadwal, tidak bisa diubah.';
    }
    final off = partner(partnerId).offDays;
    final k = dateKey(d);
    if (!off.remove(k)) off.add(k);
    notifyListeners();
    return null;
  }

  // ---------- Pesanan ----------

  String _log(String who, String text) =>
      '${fmtDate(dateOnly(DateTime.now()))} · $who: $text';

  String? createBooking({
    required String partnerId,
    required DateTime start,
    required int days,
    required PickedLocation location,
    required String notes,
    required PaymentMethod payment,
  }) {
    final s = dateOnly(start);
    final c = conflictDays(partnerId, s, days);
    if (c.isNotEmpty) {
      return 'Jadwal bentrok pada ${fmtDate(c.first)}. Pilih tanggal lain.';
    }
    final p = partner(partnerId);
    final b = Booking(
      id: 'b${_seq++}',
      customerName: customerName,
      partnerId: partnerId,
      start: s,
      days: days,
      location: location,
      notes: notes,
      payment: payment,
      price: p.rate * days,
    );
    b.revisions.add(_log(
      'Pelanggan',
      'Pesanan diajukan (${fmtDate(s)}, $days hari, ${rupiah(b.price)}).',
    ));
    bookings.add(b);
    notifyListeners();
    return null;
  }

  String? accept(String id) {
    final b = booking(id);
    final c = conflictDays(b.partnerId, b.start, b.days, ignoreId: id);
    if (c.isNotEmpty) {
      return 'Tidak bisa diterima: jadwal bentrok pada ${fmtDate(c.first)}.';
    }
    b.status = BookingStatus.dikonfirmasi;
    b.milestones = _defaultMilestones(b, partner(b.partnerId).name);
    b.revisions.add(_log('Mitra', 'Pesanan diterima, jadwal dikunci.'));
    notifyListeners();
    return null;
  }

  void reject(String id) {
    final b = booking(id);
    b.status = BookingStatus.ditolak;
    b.revisions.add(_log('Mitra', 'Pesanan ditolak.'));
    notifyListeners();
  }

  void cancel(String id) {
    final b = booking(id);
    b.status = BookingStatus.dibatalkan;
    b.revisions.add(_log('Pelanggan', 'Pesanan dibatalkan.'));
    notifyListeners();
  }

  void start(String id) {
    booking(id).status = BookingStatus.berjalan;
    notifyListeners();
  }

  int pendingTasks(String id) => booking(id)
      .milestones
      .expand((m) => m.tasks)
      .where((t) => t.status != TaskStatus.selesai)
      .length;

  /// Laporan progres (foto opsional) saat pekerjaan berjalan.
  void addReport(String id, String note, List<Uint8List> photos) {
    booking(id).reports.add(ProgressReport(
          time: DateTime.now(),
          note: note,
          photos: List.of(photos),
        ));
    notifyListeners();
  }

  /// Mitra menandai selesai: semua tugas harus selesai + minimal 1 foto bukti.
  String? markDone(String id, String note, List<Uint8List> photos) {
    final b = booking(id);
    final pending = pendingTasks(id);
    if (pending > 0) return 'Masih ada $pending tugas yang belum selesai.';
    if (photos.isEmpty) return 'Tambahkan minimal 1 foto bukti penyelesaian.';
    b.reports.add(ProgressReport(
      time: DateTime.now(),
      note: note,
      photos: List.of(photos),
      isFinal: true,
    ));
    b.status = BookingStatus.menungguKonfirmasi;
    b.revisions.add(_log('Mitra', 'Pekerjaan ditandai selesai (disertai bukti foto).'));
    notifyListeners();
    return null;
  }

  void confirmDone(String id, int rating, String review) {
    final b = booking(id);
    b.status = BookingStatus.selesai;
    b.rating = rating;
    b.review = review.isEmpty ? null : review;
    b.revisions.add(_log('Pelanggan', 'Menyelesaikan pesanan (rating $rating/5).'));
    notifyListeners();
  }

  void addRevision(String id, String who, String text) {
    booking(id).revisions.add(_log(who, text));
    notifyListeners();
  }

  // ---------- Tugas ----------

  void setTaskStatus(JobTask t, TaskStatus s) {
    t.status = s;
    notifyListeners();
  }

  void addTask(Milestone m, String title, String assignee, DateTime due) {
    m.tasks.add(JobTask(title: title, assignee: assignee, due: due));
    notifyListeners();
  }

  List<Milestone> _defaultMilestones(Booking b, String who) => [
        Milestone('Milestone 1 · Persiapan', [
          JobTask(title: 'Survei lokasi & siapkan alat', assignee: who, due: b.start),
        ]),
        Milestone('Milestone 2 · Pengerjaan', [
          JobTask(title: 'Pengerjaan utama', assignee: who, due: b.end),
        ]),
        Milestone('Milestone 3 · Finalisasi', [
          JobTask(title: 'Rapikan & dokumentasi hasil', assignee: who, due: b.end),
        ]),
      ];

  // ---------- Performa mitra ----------

  List<Booking> reviewsOf(String pid) =>
      bookings.where((b) => b.partnerId == pid && b.rating != null).toList();

  double? avgRating(String pid) {
    final r = reviewsOf(pid);
    if (r.isEmpty) return null;
    return r.fold<int>(0, (s, b) => s + b.rating!) / r.length;
  }

  int completedCount(String pid) => bookings
      .where((b) => b.partnerId == pid && b.status == BookingStatus.selesai)
      .length;

  String badge(String pid) {
    final done = completedCount(pid);
    final avg = avgRating(pid) ?? 0;
    if (done >= 3 && avg >= 4.5) return 'Mitra Terpercaya';
    if (done >= 1) return 'Mitra Aktif';
    return 'Mitra Baru';
  }

  String ratingText(String pid) {
    final avg = avgRating(pid);
    if (avg == null) return 'Baru';
    return avg.toStringAsFixed(1);
  }

  // ---------- Data contoh ----------

  void _seed() {
    final today = dateOnly(DateTime.now());
    DateTime plus(int n) => DateTime(today.year, today.month, today.day + n);

    partners.addAll([
      Partner(id: 'p1', name: 'Pak Slamet', category: ServiceCategory.pertanian,
          skills: 'Buruh tani: tanam, panen, olah lahan', area: 'Sukolilo',
          rate: 150000, lat: -7.2905, lng: 112.7950),
      Partner(id: 'p2', name: 'Tim Karya Bangun', category: ServiceCategory.bangunan,
          skills: 'Tukang bangunan: renovasi, cat, pasang keramik', area: 'Rungkut',
          rate: 350000, lat: -7.3290, lng: 112.7690, members: 2),
      Partner(id: 'p3', name: 'Mas Dimas Angkut', category: ServiceCategory.angkut,
          skills: 'Pindahan rumah, angkut barang (pickup)', area: 'Gubeng',
          rate: 250000, lat: -7.2755, lng: 112.7490),
      Partner(id: 'p4', name: 'Rudi Servis Elektronik', category: ServiceCategory.elektronik,
          skills: 'Servis TV, kulkas, mesin cuci, AC', area: 'Wonokromo',
          rate: 100000, lat: -7.3050, lng: 112.7370),
      Partner(id: 'p5', name: 'Andi Kuli Panggul', category: ServiceCategory.lainnya,
          skills: 'Kuli angkut, bongkar muat', area: 'Tambaksari',
          rate: 120000, lat: -7.2570, lng: 112.7660),
    ]);
    partner('p1').offDays.add(dateKey(plus(1)));

    const home = PickedLocation(
      lat: -7.2467, lng: 112.7889,
      address: 'Jl. Kenjeran No. 12, Surabaya, Jawa Timur',
    );

    final b1 = Booking(
      id: 'b1', customerName: customerName, partnerId: 'p2',
      start: plus(2), days: 3, location: home,
      notes: 'Cat ulang ruang tamu dan teras.',
      payment: PaymentMethod.tunai, price: 350000 * 3,
      status: BookingStatus.dikonfirmasi,
    );
    b1.milestones = _defaultMilestones(b1, 'Tim Karya Bangun');
    b1.revisions.add(_log('Pelanggan', 'Pesanan diajukan.'));
    b1.revisions.add(_log('Mitra', 'Pesanan diterima, jadwal dikunci.'));

    final b2 = Booking(
      id: 'b2', customerName: 'Sari Wulandari', partnerId: 'p2',
      start: plus(7), days: 2,
      location: const PickedLocation(
        lat: -7.3180, lng: 112.7800,
        address: 'Perum Wiguna Blok C5, Rungkut, Surabaya',
      ),
      notes: 'Pasang keramik dapur.',
      payment: PaymentMethod.digital, price: 350000 * 2,
    );
    b2.revisions.add(_log('Pelanggan', 'Pesanan diajukan.'));

    final b3 = Booking(
      id: 'b3', customerName: customerName, partnerId: 'p2',
      start: plus(-10), days: 2, location: home,
      notes: 'Perbaiki pagar.',
      payment: PaymentMethod.digital, price: 350000 * 2,
      status: BookingStatus.selesai,
    )
      ..rating = 5
      ..review = 'Rapi dan tepat waktu.';
    b3.milestones = _defaultMilestones(b3, 'Tim Karya Bangun');
    for (final t in b3.milestones.expand((m) => m.tasks)) {
      t.status = TaskStatus.selesai;
    }
    b3.reports.add(ProgressReport(
      time: plus(-9),
      note: 'Pagar selesai dicat dan dipasang.',
      photos: [],
      isFinal: true,
    ));

    bookings.addAll([b1, b2, b3]);
  }
}
