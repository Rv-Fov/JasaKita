import 'package:flutter/material.dart';
import 'models.dart';
import 'ui.dart';

Color slotColor(SlotStatus s) => switch (s) {
      SlotStatus.tersedia => const Color(0xFFBBF7D0),
      SlotStatus.terjadwal => const Color(0xFFBFDBFE),
      SlotStatus.tidakTersedia => const Color(0xFFD1D5DB),
    };

String slotLabel(SlotStatus s) => switch (s) {
      SlotStatus.tersedia => 'Tersedia',
      SlotStatus.terjadwal => 'Terjadwal',
      SlotStatus.tidakTersedia => 'Tidak tersedia',
    };

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) => Pill(status.label, color: status.color);
}

class SlotLegend extends StatelessWidget {
  const SlotLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final s in SlotStatus.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: slotColor(s), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(slotLabel(s), style: const TextStyle(fontSize: 12, color: kMuted)),
            ],
          ),
      ],
    );
  }
}

/// Kalender bulanan dengan warna status ketersediaan per hari.
class AvailabilityCalendar extends StatefulWidget {
  const AvailabilityCalendar({super.key, required this.statusOf, this.onDayTap});

  final SlotStatus Function(DateTime day) statusOf;
  final void Function(DateTime day)? onDayTap;

  @override
  State<AvailabilityCalendar> createState() => _AvailabilityCalendarState();
}

class _AvailabilityCalendarState extends State<AvailabilityCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int n) => setState(() => _month = DateTime(_month.year, _month.month + n));

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday - 1; // Senin = 0

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            Text(
              '${bulanPanjang[_month.month - 1]} ${_month.year}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: [
            for (final h in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
              Expanded(
                child: Center(
                  child: Text(h, style: const TextStyle(fontSize: 12, color: kMuted)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < offset; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              _cell(DateTime(_month.year, _month.month, d), today),
          ],
        ),
      ],
    );
  }

  Widget _cell(DateTime date, DateTime today) {
    final past = date.isBefore(today);
    final status = widget.statusOf(date);
    final isToday = date == today;
    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: (past || widget.onDayTap == null) ? null : () => widget.onDayTap!(date),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: past ? Colors.transparent : slotColor(status),
            border: isToday ? Border.all(color: kPrimary, width: 2) : null,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: past ? Colors.grey.shade400 : kInk,
            ),
          ),
        ),
      ),
    );
  }
}
