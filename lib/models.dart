import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

enum ServiceCategory {
  pertanian('Pertanian', Icons.grass, Color(0xFF2E9E5B)),
  bangunan('Bangunan', Icons.construction, Color(0xFFE8833A)),
  angkut('Angkut', Icons.local_shipping, Color(0xFF3B82F6)),
  elektronik('Servis Elektronik', Icons.build, Color(0xFF8B5CF6)),
  lainnya('Lainnya', Icons.more_horiz, Color(0xFF64748B));

  const ServiceCategory(this.label, this.icon, this.tint);
  final String label;
  final IconData icon;
  final Color tint;
}

/// Status satu hari pada kalender ketersediaan mitra.
enum SlotStatus { tersedia, terjadwal, tidakTersedia }

enum BookingStatus {
  diajukan('Menunggu respon', Color(0xFFF59E0B)),
  dikonfirmasi('Terkonfirmasi', Color(0xFF3B82F6)),
  berjalan('Berjalan', Color(0xFF6366F1)),
  menungguKonfirmasi('Menunggu konfirmasi', Color(0xFF8B5CF6)),
  selesai('Selesai', Color(0xFF16A34A)),
  ditolak('Ditolak', Color(0xFFDC2626)),
  dibatalkan('Dibatalkan', Color(0xFF6B7280));

  const BookingStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum PaymentMethod {
  digital('Digital'),
  tunai('Tunai');

  const PaymentMethod(this.label);
  final String label;
}

enum TaskStatus {
  belum('Belum mulai', Icons.radio_button_unchecked),
  proses('Dikerjakan', Icons.timelapse),
  selesai('Selesai', Icons.check_circle);

  const TaskStatus(this.label, this.icon);
  final String label;
  final IconData icon;
}

class PickedLocation {
  const PickedLocation({required this.lat, required this.lng, required this.address});
  final double lat;
  final double lng;
  final String address;
}

class Partner {
  Partner({
    required this.id,
    required this.name,
    required this.category,
    required this.skills,
    required this.area,
    required this.rate,
    required this.lat,
    required this.lng,
    this.members = 1,
  });

  final String id;
  final String name;
  final ServiceCategory category;
  final String skills;
  final String area;
  final int rate; // Rp per hari
  final double lat;
  final double lng;
  final int members; // maks. 2 termasuk ketua
  final Set<String> offDays = {}; // hari libur (dateKey)

  bool get isTeam => members > 1;
}

class JobTask {
  JobTask({
    required this.title,
    required this.assignee,
    required this.due,
    this.status = TaskStatus.belum,
  });

  String title;
  String assignee;
  DateTime due;
  TaskStatus status;
}

class Milestone {
  Milestone(this.title, this.tasks);
  final String title;
  final List<JobTask> tasks;
}

/// Laporan progres / bukti penyelesaian dari mitra (dengan foto).
class ProgressReport {
  ProgressReport({
    required this.time,
    required this.note,
    required this.photos,
    this.isFinal = false,
  });

  final DateTime time;
  final String note;
  final List<Uint8List> photos;
  final bool isFinal;
}

class Booking {
  Booking({
    required this.id,
    required this.customerName,
    required this.partnerId,
    required this.start,
    required this.days,
    required this.location,
    required this.notes,
    required this.payment,
    required this.price,
    this.status = BookingStatus.diajukan,
  });

  final String id;
  final String customerName;
  final String partnerId;
  final DateTime start;
  final int days;
  final PickedLocation location;
  final String notes;
  final PaymentMethod payment;
  final int price;

  BookingStatus status;
  List<Milestone> milestones = [];
  List<String> revisions = []; // jejak revisi kesepakatan
  List<ProgressReport> reports = [];
  int? rating;
  String? review;

  DateTime get end => DateTime(start.year, start.month, start.day + days - 1);

  bool covers(DateTime d) {
    final x = dateOnly(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  /// Persentase tugas yang selesai (0..1).
  double get progress {
    final tasks = milestones.expand((m) => m.tasks).toList();
    if (tasks.isEmpty) return 0;
    return tasks.where((t) => t.status == TaskStatus.selesai).length / tasks.length;
  }
}

// ---------- Helper ----------

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

const bulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const bulanPanjang = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String fmtDate(DateTime d) => '${d.day} ${bulanSingkat[d.month - 1]} ${d.year}';

String fmtDateTime(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${fmtDate(d)} · $h:$m';
}

String rupiah(int v) {
  final s = v.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => '.',
      );
  return 'Rp$s';
}

double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180;
  const r = 6371000.0;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

String fmtDistance(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
