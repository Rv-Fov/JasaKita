import 'package:flutter/material.dart';
import 'models.dart';
import 'order_detail.dart';
import 'shared.dart';
import 'store.dart';
import 'ui.dart';

class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});

  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const tabs = [_JobsTab(), _ScheduleTab(), _PerformanceTab()];
    return Scaffold(
      body: tabs[_tab],
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final newReq = store.bookings
              .where((b) =>
                  b.partnerId == store.currentPartnerId &&
                  b.status == BookingStatus.diajukan)
              .length;
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  label: Text('$newReq'),
                  isLabelVisible: newReq > 0,
                  child: const Icon(Icons.assignment_outlined),
                ),
                selectedIcon: const Icon(Icons.assignment),
                label: 'Pekerjaan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Jadwal',
              ),
              const NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'Performa',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.title, required this.subtitle, this.child});
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: kGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 22),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Ganti peran',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(subtitle, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            if (child != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---------- Pekerjaan ----------

class _JobsTab extends StatelessWidget {
  const _JobsTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.partner(store.currentPartnerId);
        final mine = store.bookings.where((b) => b.partnerId == me.id).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
        final requests = mine.where((b) => b.status == BookingStatus.diajukan).toList();
        final active = mine
            .where((b) =>
                b.status == BookingStatus.dikonfirmasi ||
                b.status == BookingStatus.berjalan ||
                b.status == BookingStatus.menungguKonfirmasi)
            .toList();
        final history = mine
            .where((b) =>
                b.status == BookingStatus.selesai ||
                b.status == BookingStatus.ditolak ||
                b.status == BookingStatus.dibatalkan)
            .toList();

        Widget empty(String t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(t, style: const TextStyle(color: kMuted)),
            );

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _GradientHeader(
              title: 'Halo, ${me.name}',
              subtitle: store.badge(me.id),
              child: Row(
                children: [
                  _HeaderStat('${requests.length}', 'Permintaan'),
                  _HeaderStat('${active.length}', 'Aktif'),
                  _HeaderStat('${store.completedCount(me.id)}', 'Selesai'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle('Permintaan baru',
                      trailing: requests.isEmpty ? null : Pill('${requests.length}', color: const Color(0xFFF59E0B))),
                  if (requests.isEmpty) empty('Belum ada permintaan baru.'),
                  for (final b in requests) _RequestCard(booking: b),
                  const SectionTitle('Pekerjaan aktif'),
                  if (active.isEmpty) empty('Belum ada pekerjaan aktif.'),
                  for (final b in active) BookingTile(booking: b, asPartner: true),
                  const SectionTitle('Riwayat'),
                  if (history.isEmpty) empty('Belum ada riwayat.'),
                  for (final b in history) BookingTile(booking: b, asPartner: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final p = store.partner(b.partnerId);
    final conflict = store.conflictDays(b.partnerId, b.start, b.days, ignoreId: b.id);
    final range = b.days > 1
        ? '${fmtDate(b.start)} – ${fmtDate(b.end)}'
        : fmtDate(b.start);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderDetailPage(bookingId: b.id, asPartner: true),
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryAvatar(p.category, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('${b.days} hari · ${b.payment.label}',
                          style: const TextStyle(color: kMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Text(rupiah(b.price),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            IconText(Icons.event, range),
            const SizedBox(height: 4),
            IconText(Icons.place_outlined, b.location.address),
            if (b.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              IconText(Icons.notes, b.notes, maxLines: 2),
            ],
            if (conflict.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Pill('Bentrok dengan jadwal/liburmu',
                  color: Color(0xFFDC2626), icon: Icons.warning_amber_rounded),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => store.reject(b.id),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final e = store.accept(b.id);
                      if (e != null) snack(context, e);
                    },
                    child: const Text('Terima'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Jadwal ----------

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context) {
    final pid = store.currentPartnerId;
    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final upcoming = store.bookings
              .where((b) =>
                  b.partnerId == pid &&
                  (b.status == BookingStatus.dikonfirmasi ||
                      b.status == BookingStatus.berjalan))
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text('Jadwal & Ketersediaan',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
              const SizedBox(height: 4),
              const Text(
                'Ketuk tanggal untuk menandai libur atau membuka jadwal.',
                style: TextStyle(color: kMuted),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  children: [
                    AvailabilityCalendar(
                      statusOf: (d) => store.slotStatus(pid, d),
                      onDayTap: (d) {
                        final err = store.toggleOff(pid, d);
                        if (err != null) snack(context, err);
                      },
                    ),
                    const SizedBox(height: 8),
                    const Align(alignment: Alignment.centerLeft, child: SlotLegend()),
                  ],
                ),
              ),
              const SectionTitle('Jadwal terkonfirmasi'),
              if (upcoming.isEmpty)
                const Text('Belum ada.', style: TextStyle(color: kMuted)),
              for (final b in upcoming) BookingTile(booking: b, asPartner: true),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Performa ----------

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab();

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 12, color: kMuted)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pid = store.currentPartnerId;
    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final reviews = store.reviewsOf(pid);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text('Performa',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  children: [
                    const Icon(Icons.military_tech, size: 56, color: Colors.amber),
                    Text(store.badge(pid),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _stat('${store.completedCount(pid)}', 'Selesai'),
                        _stat(store.ratingText(pid), 'Rating'),
                        _stat('${reviews.length}', 'Ulasan'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Skor bukan hukuman otomatis: penilaian mempertimbangkan konteks '
                'keterlambatan, bukti, dan konfirmasi kedua pihak.',
                style: TextStyle(fontSize: 12, color: kMuted),
              ),
              const SectionTitle('Ulasan pelanggan'),
              if (reviews.isEmpty)
                const Text('Belum ada ulasan.', style: TextStyle(color: kMuted)),
              for (final r in reviews)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= r.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(r.customerName,
                                style: const TextStyle(color: kMuted, fontSize: 12)),
                          ],
                        ),
                        if (r.review != null) ...[
                          const SizedBox(height: 6),
                          Text(r.review!),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
