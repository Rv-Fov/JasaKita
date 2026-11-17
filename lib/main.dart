import 'package:flutter/material.dart';
import 'customer.dart';
import 'models.dart';
import 'partner.dart';
import 'ui.dart';

/// Nama aplikasi belum diputuskan (lihat slide 18) — ganti di sini.
const appName = 'JasaKita';

void main() => runApp(const JasaApp());

class JasaApp extends StatelessWidget {
  const JasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const RoleGate(),
    );
  }
}

/// Layar awal: pilih peran. (Login sungguhan menyusul setelah backend dipilih.)
class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  Widget _roleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: kPrimary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kMuted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: kGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.handshake, size: 44, color: kPrimary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Menghubungkan jasa. Merapikan pekerjaan.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final c in ServiceCategory.values)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.icon, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(c.label,
                                  style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text('Masuk sebagai',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _roleCard(
                    context,
                    icon: Icons.person_search,
                    title: 'Pelanggan',
                    subtitle: 'Cari, pesan, dan pantau pekerjaan',
                    page: const CustomerShell(),
                  ),
                  const SizedBox(height: 12),
                  _roleCard(
                    context,
                    icon: Icons.engineering,
                    title: 'Mitra',
                    subtitle: 'Kelola jadwal, pesanan, dan progres',
                    page: const PartnerShell(),
                  ),
                  const Spacer(),
                  const Center(
                    child: Text(
                      'Mode demo: data disimpan di memori (tanpa backend).',
                      style: TextStyle(fontSize: 12, color: kMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
