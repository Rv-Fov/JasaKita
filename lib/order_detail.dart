import 'package:flutter/material.dart';
import 'location.dart';
import 'media.dart';
import 'models.dart';
import 'shared.dart';
import 'store.dart';
import 'ui.dart';

String _rangeText(Booking b) => b.days > 1
    ? '${fmtDate(b.start)} – ${fmtDate(b.end)}'
    : fmtDate(b.start);

class BookingTile extends StatelessWidget {
  const BookingTile({super.key, required this.booking, required this.asPartner});
  final Booking booking;
  final bool asPartner;

  @override
  Widget build(BuildContext context) {
    final p = store.partner(booking.partnerId);
    final title = asPartner ? booking.customerName : p.name;
    final running = booking.status == BookingStatus.berjalan ||
        booking.status == BookingStatus.menungguKonfirmasi;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderDetailPage(bookingId: booking.id, asPartner: asPartner),
        )),
        child: Column(
          children: [
            Row(
              children: [
                CategoryAvatar(p.category, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(p.category.label, style: const TextStyle(color: kMuted, fontSize: 12)),
                    ],
                  ),
                ),
                StatusChip(booking.status),
              ],
            ),
            const SizedBox(height: 12),
            IconText(Icons.event, _rangeText(booking)),
            const SizedBox(height: 4),
            IconText(Icons.place_outlined, booking.location.address),
            if (running) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: booking.progress,
                        minHeight: 6,
                        backgroundColor: kBorder,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(booking.progress * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Langkah status: Diajukan → Dikonfirmasi → Berjalan → Selesai.
class StatusStepper extends StatelessWidget {
  const StatusStepper(this.status, {super.key});
  final BookingStatus status;

  static const _labels = ['Diajukan', 'Konfirmasi', 'Berjalan', 'Selesai'];

  int get _index => switch (status) {
        BookingStatus.diajukan => 0,
        BookingStatus.dikonfirmasi => 1,
        BookingStatus.berjalan => 2,
        BookingStatus.menungguKonfirmasi => 2,
        BookingStatus.selesai => 3,
        _ => -1,
      };

  @override
  Widget build(BuildContext context) {
    final idx = _index;
    if (idx < 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: status.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Pesanan ${status.label.toLowerCase()}',
          style: TextStyle(color: status.color, fontWeight: FontWeight.w700),
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= idx ? kPrimary : kBorder),
                      ),
                    ),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: i <= idx ? kPrimary : kBorder,
                      child: Icon(
                        i < idx || status == BookingStatus.selesai
                            ? Icons.check
                            : Icons.circle,
                        size: i <= idx ? 14 : 6,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == _labels.length - 1
                            ? Colors.transparent
                            : (i < idx ? kPrimary : kBorder),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500,
                    color: i <= idx ? kInk : kMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.bookingId, required this.asPartner});
  final String bookingId;
  final bool asPartner;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final b = store.booking(bookingId);
        final p = store.partner(b.partnerId);
        final actions = _actions(context, b);
        return Scaffold(
          appBar: AppBar(title: const Text('Detail Pesanan')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              AppCard(child: StatusStepper(b.status)),
              const SizedBox(height: 12),
              _summary(context, b, p),
              const SizedBox(height: 12),
              _locationCard(b),
              const SizedBox(height: 12),
              _timeline(context, b, p),
              const SizedBox(height: 12),
              _reports(context, b),
              const SizedBox(height: 12),
              _revisions(context, b),
              if (b.rating != null) ...[
                const SizedBox(height: 12),
                _reviewCard(b),
              ],
            ],
          ),
          bottomNavigationBar: actions.isEmpty
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: kBorder)),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(child: actions[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ---------- Aksi bawah ----------

  List<Widget> _actions(BuildContext context, Booking b) {
    if (asPartner) {
      switch (b.status) {
        case BookingStatus.diajukan:
          return [
            OutlinedButton(
              onPressed: () => store.reject(b.id),
              child: const Text('Tolak'),
            ),
            FilledButton(
              onPressed: () {
                final e = store.accept(b.id);
                if (e != null) snack(context, e);
              },
              child: const Text('Terima'),
            ),
          ];
        case BookingStatus.dikonfirmasi:
          return [
            FilledButton(
              onPressed: () => store.start(b.id),
              child: const Text('Mulai pekerjaan'),
            ),
          ];
        case BookingStatus.berjalan:
          return [
            OutlinedButton.icon(
              onPressed: () => _report(context, b),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Lapor progres'),
            ),
            FilledButton(
              onPressed: () => _finish(context, b),
              child: const Text('Selesaikan'),
            ),
          ];
        default:
          return [];
      }
    }
    switch (b.status) {
      case BookingStatus.diajukan:
      case BookingStatus.dikonfirmasi:
        return [
          OutlinedButton(
            onPressed: () => store.cancel(b.id),
            child: const Text('Batalkan pesanan'),
          ),
        ];
      case BookingStatus.menungguKonfirmasi:
        return [
          FilledButton(
            onPressed: () => _review(context, b),
            child: const Text('Konfirmasi selesai & ulasan'),
          ),
        ];
      default:
        return [];
    }
  }

  Future<void> _report(BuildContext context, Booking b) async {
    final r = await showReportSheet(
      context,
      title: 'Lapor progres',
      hint: 'Apa yang sudah dikerjakan hari ini?',
      requirePhoto: false,
    );
    if (r != null) store.addReport(b.id, r.note, r.photos);
  }

  Future<void> _finish(BuildContext context, Booking b) async {
    final pending = store.pendingTasks(b.id);
    if (pending > 0) {
      snack(context, 'Masih ada $pending tugas yang belum selesai.');
      return;
    }
    final r = await showReportSheet(
      context,
      title: 'Bukti penyelesaian',
      hint: 'Ringkasan hasil pekerjaan',
      requirePhoto: true,
    );
    if (r == null) return;
    final e = store.markDone(b.id, r.note, r.photos);
    if (e != null && context.mounted) snack(context, e);
  }

  // ---------- Kartu ----------

  Widget _summary(BuildContext context, Booking b, Partner p) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(p.category, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asPartner ? b.customerName : p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Text(
                      asPartner ? 'Pelanggan · ${p.category.label}' : p.category.label,
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              StatusChip(b.status),
            ],
          ),
          const Divider(height: 28),
          IconText(Icons.event, '${_rangeText(b)} (${b.days} hari)', color: kInk),
          const SizedBox(height: 8),
          IconText(Icons.notes, b.notes.isEmpty ? '-' : b.notes, color: kInk, maxLines: 4),
          const SizedBox(height: 8),
          IconText(
            Icons.payments_outlined,
            '${rupiah(b.price)} · ${b.payment.label}',
            color: kInk,
          ),
        ],
      ),
    );
  }

  Widget _locationCard(Booking b) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiniMap(lat: b.location.lat, lng: b.location.lng),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconText(Icons.place, b.location.address, color: kInk, maxLines: 3),
          ),
        ],
      ),
    );
  }

  Widget _timeline(BuildContext context, Booking b, Partner p) {
    final canEdit = asPartner && b.status == BookingStatus.berjalan;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Timeline pekerjaan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (b.milestones.isNotEmpty)
                Text(
                  '${(b.progress * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary),
                ),
            ],
          ),
          if (b.milestones.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: b.progress,
                minHeight: 8,
                backgroundColor: kBorder,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (b.milestones.isEmpty)
            const Text(
              'Timeline dibuat otomatis setelah mitra menerima pesanan.',
              style: TextStyle(color: kMuted),
            ),
          for (final m in b.milestones) ...[
            const SizedBox(height: 8),
            Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final t in m.tasks)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  t.status.icon,
                  color: t.status == TaskStatus.selesai ? const Color(0xFF16A34A) : kMuted,
                ),
                title: Text(t.title),
                subtitle: Text('${t.assignee} · target ${fmtDate(t.due)} · ${t.status.label}'),
                trailing: canEdit
                    ? PopupMenuButton<TaskStatus>(
                        onSelected: (s) => store.setTaskStatus(t, s),
                        itemBuilder: (_) => [
                          for (final s in TaskStatus.values)
                            PopupMenuItem(value: s, child: Text(s.label)),
                        ],
                      )
                    : null,
              ),
            if (canEdit)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah tugas'),
                  onPressed: () async {
                    final t = await _askText(context, 'Tugas baru', 'Nama tugas');
                    if (t != null && t.isNotEmpty) {
                      store.addTask(m, t, p.name, b.end);
                    }
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _reports(BuildContext context, Booking b) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Laporan & bukti foto',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Pill('${b.reports.length}', color: kMuted),
            ],
          ),
          const SizedBox(height: 4),
          if (b.reports.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                asPartner
                    ? 'Belum ada laporan. Gunakan "Lapor progres" saat pekerjaan berjalan.'
                    : 'Belum ada laporan dari mitra.',
                style: const TextStyle(color: kMuted),
              ),
            ),
          for (final r in b.reports.reversed)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(
                        r.isFinal ? 'Bukti selesai' : 'Progres',
                        color: r.isFinal ? const Color(0xFF16A34A) : kPrimary,
                        icon: r.isFinal ? Icons.verified : Icons.update,
                      ),
                      const SizedBox(width: 8),
                      Text(fmtDateTime(r.time),
                          style: const TextStyle(color: kMuted, fontSize: 12)),
                    ],
                  ),
                  if (r.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(r.note),
                  ],
                  if (r.photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    PhotoThumbs(photos: r.photos),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _revisions(BuildContext context, Booking b) {
    final open = b.status != BookingStatus.selesai &&
        b.status != BookingStatus.ditolak &&
        b.status != BookingStatus.dibatalkan;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Revisi kesepakatan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (open)
                IconButton(
                  tooltip: 'Catat revisi',
                  icon: const Icon(Icons.add_comment_outlined),
                  onPressed: () async {
                    final t = await _askText(
                      context,
                      'Catat revisi',
                      'Mis. jadwal mundur 1 hari, harga disesuaikan…',
                    );
                    if (t != null && t.isNotEmpty) {
                      store.addRevision(b.id, asPartner ? 'Mitra' : 'Pelanggan', t);
                    }
                  },
                ),
            ],
          ),
          for (final r in b.revisions.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('• $r', style: const TextStyle(fontSize: 13, color: kMuted)),
            ),
        ],
      ),
    );
  }

  Widget _reviewCard(Booking b) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ulasan pelanggan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= b.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                  ),
              ],
            ),
            if (b.review != null) Text(b.review!),
          ],
        ),
      );

  // ---------- Dialog ----------

  Future<String?> _askText(BuildContext context, String title, String hint) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<void> _review(BuildContext context, Booking b) async {
    var stars = 5;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Konfirmasi selesai'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    GestureDetector(
                      onTap: () => setS(() => stars = i),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Tulis ulasan (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) store.confirmDone(b.id, stars, ctrl.text.trim());
    ctrl.dispose();
  }
}
