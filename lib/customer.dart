import 'package:flutter/material.dart';
import 'location.dart';
import 'models.dart';
import 'order_detail.dart';
import 'shared.dart';
import 'store.dart';
import 'ui.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab == 0 ? const _BrowseTab() : const _OrdersTab(),
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final active = store.bookings
              .where((b) =>
                  b.customerName == store.customerName &&
                  (b.status == BookingStatus.diajukan ||
                      b.status == BookingStatus.dikonfirmasi ||
                      b.status == BookingStatus.berjalan ||
                      b.status == BookingStatus.menungguKonfirmasi))
              .length;
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('$active'),
                  isLabelVisible: active > 0,
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                selectedIcon: const Icon(Icons.receipt_long),
                label: 'Pesanan',
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Beranda ----------

class _BrowseTab extends StatefulWidget {
  const _BrowseTab();

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
  String _query = '';
  ServiceCategory? _category;
  bool _onlyAvailable = false;

  Future<void> _pickLocation() async {
    final r = await Navigator.of(context).push<PickedLocation>(MaterialPageRoute(
      builder: (_) => LocationPickerPage(initial: store.myLocation),
    ));
    if (r != null) store.setMyLocation(r);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final today = dateOnly(DateTime.now());
        final list = store.partners.where((p) {
          if (_category != null && p.category != _category) return false;
          final hay = '${p.name} ${p.skills} ${p.category.label}'.toLowerCase();
          if (_query.isNotEmpty && !hay.contains(_query.toLowerCase())) return false;
          if (_onlyAvailable && store.slotStatus(p.id, today) != SlotStatus.tersedia) {
            return false;
          }
          return true;
        }).toList();
        if (store.myLocation != null) {
          list.sort((a, b) => store.distanceTo(a)!.compareTo(store.distanceTo(b)!));
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _categories(),
                  SectionTitle(
                    store.myLocation == null ? 'Mitra tersedia' : 'Mitra terdekat',
                    trailing: FilterChip(
                      label: const Text('Tersedia hari ini'),
                      selected: _onlyAvailable,
                      onSelected: (v) => setState(() => _onlyAvailable = v),
                    ),
                  ),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Tidak ada mitra yang cocok.')),
                    ),
                  for (final p in list) _PartnerCard(partner: p, today: today),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final loc = store.myLocation;
    return Container(
      decoration: const BoxDecoration(
        gradient: kGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
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
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${store.customerName.split(' ').first}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Mau cari jasa apa hari ini?',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickLocation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loc?.address ?? 'Atur lokasimu untuk melihat jarak mitra',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari tukang, buruh tani, servis…',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categories() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          for (final c in ServiceCategory.values)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _category = _category == c ? null : c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _category == c ? c.tint : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CategoryAvatar(c, size: 46),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _category == c ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner, required this.today});
  final Partner partner;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final free = store.slotStatus(partner.id, today) == SlotStatus.tersedia;
    final dist = store.distanceTo(partner);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PartnerDetailPage(partnerId: partner.id),
        )),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryAvatar(partner.category, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              partner.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          if (store.badge(partner.id) == 'Mitra Terpercaya')
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified, size: 16, color: kPrimary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        partner.skills,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Pill(store.ratingText(partner.id), color: const Color(0xFFD97706), icon: Icons.star_rounded),
                if (dist != null) Pill(fmtDistance(dist), color: kMuted, icon: Icons.near_me),
                if (partner.isTeam) Pill('Tim ${partner.members} orang', color: kMuted, icon: Icons.group),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: rupiah(partner.rate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: kPrimary,
                          ),
                        ),
                        const TextSpan(
                          text: ' /hari',
                          style: TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                Pill(
                  free ? 'Tersedia hari ini' : 'Sibuk hari ini',
                  color: free ? const Color(0xFF16A34A) : kMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Detail mitra ----------

class PartnerDetailPage extends StatelessWidget {
  const PartnerDetailPage({super.key, required this.partnerId});
  final String partnerId;

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.partner(partnerId);
        final reviews = store.reviewsOf(p.id);
        final dist = store.distanceTo(p);
        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: kGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CategoryAvatar(p.category, size: 64),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${p.category.label} · ${p.area}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _stat(store.ratingText(p.id), 'Rating'),
                          _stat('${store.completedCount(p.id)}', 'Pekerjaan selesai'),
                          _stat(dist == null ? '-' : fmtDistance(dist), 'Jarak'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              Pill(store.badge(p.id), icon: Icons.verified),
                              Pill(
                                p.isTeam ? 'Tim ${p.members} orang' : 'Individu',
                                color: kMuted,
                                icon: p.isTeam ? Icons.group : Icons.person,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(p.skills),
                        ],
                      ),
                    ),
                    const SectionTitle('Kalender ketersediaan'),
                    AppCard(
                      child: Column(
                        children: [
                          AvailabilityCalendar(statusOf: (d) => store.slotStatus(p.id, d)),
                          const SizedBox(height: 8),
                          const Align(alignment: Alignment.centerLeft, child: SlotLegend()),
                        ],
                      ),
                    ),
                    if (reviews.isNotEmpty) ...[
                      const SectionTitle('Ulasan'),
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
                                        i <= r.rating!
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
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
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Tarif', style: TextStyle(color: kMuted, fontSize: 12)),
                        Text(
                          '${rupiah(p.rate)}/hari',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BookingPage(partnerId: p.id),
                        )),
                        child: const Text('Ajukan Pesanan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Form pemesanan ----------

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, required this.partnerId});
  final String partnerId;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _notes = TextEditingController();
  DateTime _start = _tomorrow();
  int _days = 1;
  PaymentMethod _pay = PaymentMethod.digital;
  PickedLocation? _place = store.myLocation;
  bool _showLocError = false;

  static DateTime _tomorrow() {
    final t = dateOnly(DateTime.now());
    return DateTime(t.year, t.month, t.day + 1);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (d != null) setState(() => _start = dateOnly(d));
  }

  Future<void> _pickPlace() async {
    final r = await Navigator.of(context).push<PickedLocation>(MaterialPageRoute(
      builder: (_) => LocationPickerPage(initial: _place),
    ));
    if (r != null) {
      setState(() {
        _place = r;
        _showLocError = false;
      });
      if (store.myLocation == null) store.setMyLocation(r);
    }
  }

  void _submit() {
    final place = _place;
    if (place == null) {
      setState(() => _showLocError = true);
      return;
    }
    final err = store.createBooking(
      partnerId: widget.partnerId,
      start: _start,
      days: _days,
      location: place,
      notes: _notes.text.trim(),
      payment: _pay,
    );
    if (err != null) {
      snack(context, err);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    nav.pop(); // form
    nav.pop(); // detail mitra
    messenger.showSnackBar(
      const SnackBar(content: Text('Pesanan diajukan. Menunggu respon mitra.')),
    );
  }

  Widget _payCard(PaymentMethod m, IconData icon, String sub) {
    final sel = _pay == m;
    return Expanded(
      child: AppCard(
        onTap: () => setState(() => _pay = m),
        color: sel ? kPrimary.withOpacity(0.06) : Colors.white,
        borderColor: sel ? kPrimary : kBorder,
        borderWidth: sel ? 2 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: sel ? kPrimary : kMuted),
            const SizedBox(height: 8),
            Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = store.partner(widget.partnerId);
    final conflicts = store.conflictDays(p.id, _start, _days);
    final price = p.rate * _days;
    final end = DateTime(_start.year, _start.month, _start.day + _days - 1);
    final place = _place;

    return Scaffold(
      appBar: AppBar(title: Text('Pesan ${p.name}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionTitle('Kapan?'),
          AppCard(
            child: Column(
              children: [
                InkWell(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: kPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tanggal mulai',
                                style: TextStyle(color: kMuted, fontSize: 12)),
                            Text(fmtDate(_start),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: kMuted),
                    ],
                  ),
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    const Icon(Icons.timelapse, color: kPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_days hari',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('s/d ${fmtDate(end)}',
                              style: const TextStyle(color: kMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _days > 1 ? () => setState(() => _days--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton.filledTonal(
                      onPressed: _days < 30 ? () => setState(() => _days++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (conflicts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Mitra tidak tersedia pada: ${conflicts.map(fmtDate).join(', ')}. '
                      'Pilih tanggal/durasi lain.',
                      style: const TextStyle(color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('Di mana?'),
          AppCard(
            padding: const EdgeInsets.all(12),
            borderColor: _showLocError ? const Color(0xFFDC2626) : kBorder,
            child: place == null
                ? InkWell(
                    onTap: _pickPlace,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Icon(Icons.add_location_alt_outlined, color: kPrimary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Pilih lokasi pengerjaan (GPS / cari alamat / peta)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (_showLocError)
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MiniMap(lat: place.lat, lng: place.lng),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: IconText(Icons.place, place.address, color: kInk, maxLines: 3),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _pickPlace,
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                        label: const Text('Ubah lokasi'),
                      ),
                    ],
                  ),
          ),
          if (_showLocError)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('Lokasi wajib dipilih.',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
            ),
          const SectionTitle('Catatan kebutuhan'),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Mis. cat ulang ruang tamu 4x5 m…'),
          ),
          const SectionTitle('Pembayaran'),
          Row(
            children: [
              _payCard(PaymentMethod.digital, Icons.account_balance_wallet_outlined,
                  'Via payment gateway'),
              const SizedBox(width: 10),
              _payCard(PaymentMethod.tunai, Icons.payments_outlined, 'Dicatat di aplikasi'),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Jadwal belum terkunci sampai mitra menerima pesanan. '
            'Harga dan jadwal bisa direvisi lewat catatan revisi.',
            style: TextStyle(fontSize: 12, color: kMuted),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Estimasi', style: TextStyle(color: kMuted, fontSize: 12)),
                    Text(rupiah(price),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: conflicts.isEmpty ? _submit : null,
                    child: const Text('Kirim Pesanan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Pesanan saya ----------

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          bool isActive(Booking b) =>
              b.status == BookingStatus.diajukan ||
              b.status == BookingStatus.dikonfirmasi ||
              b.status == BookingStatus.berjalan ||
              b.status == BookingStatus.menungguKonfirmasi;
          final list = store.bookings
              .where((b) => b.customerName == store.customerName && isActive(b) != _history)
              .toList()
            ..sort((a, b) => b.start.compareTo(a.start));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text('Pesanan Saya',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Aktif')),
                  ButtonSegment(value: true, label: Text('Riwayat')),
                ],
                selected: {_history},
                onSelectionChanged: (s) => setState(() => _history = s.first),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: kMuted),
                      SizedBox(height: 8),
                      Text('Belum ada pesanan.', style: TextStyle(color: kMuted)),
                    ],
                  ),
                ),
              for (final b in list) BookingTile(booking: b, asPartner: false),
            ],
          );
        },
      ),
    );
  }
}
