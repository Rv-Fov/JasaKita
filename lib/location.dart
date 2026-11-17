import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'models.dart';
import 'ui.dart';

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgentPackage = 'com.jasakita.app';
const _defaultCenter = LatLng(-7.2575, 112.7521); // Surabaya

class LocationException implements Exception {
  LocationException(this.message);
  final String message;
}

/// Ambil posisi GPS saat ini (minta izin bila perlu).
Future<LatLng> currentGpsPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw LocationException('Layanan lokasi (GPS) belum aktif.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied) {
    throw LocationException('Izin lokasi ditolak.');
  }
  if (perm == LocationPermission.deniedForever) {
    throw LocationException('Izin lokasi ditolak permanen. Aktifkan lewat pengaturan.');
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
  return LatLng(pos.latitude, pos.longitude);
}

/// Cari alamat & reverse geocoding lewat Nominatim (OpenStreetMap).
class GeoService {
  static const _host = 'nominatim.openstreetmap.org';

  static Map<String, String> get _headers =>
      kIsWeb ? const {} : const {'User-Agent': 'jasakita-student-app/0.2'};

  static Future<List<PickedLocation>> search(String q) async {
    final uri = Uri.https(_host, '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '6',
      'countrycodes': 'id',
      'accept-language': 'id',
    });
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final list = jsonDecode(res.body) as List;
    return [
      for (final e in list)
        PickedLocation(
          lat: double.parse('${e['lat']}'),
          lng: double.parse('${e['lon']}'),
          address: '${e['display_name']}',
        ),
    ];
  }

  static Future<String> reverse(double lat, double lng) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': '$lat',
      'lon': '$lng',
      'format': 'jsonv2',
      'accept-language': 'id',
    });
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final name = json['display_name'];
    return name is String ? name : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}

/// Peta kecil (pratinjau, tidak bisa digeser) dengan satu penanda.
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, required this.lat, required this.lng, this.height = 140});
  final double lat;
  final double lng;
  final double height;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgentPackage),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layar pilih lokasi: cari alamat, pakai GPS, atau geser peta (pin di tengah).
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, this.initial});
  final PickedLocation? initial;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _reverseTimer;
  Timer? _searchTimer;

  late LatLng _center;
  String _address = '';
  bool _loadingAddress = false;
  bool _locating = false;
  bool _searching = false;
  String? _searchError;
  List<PickedLocation> _results = [];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _center = i == null ? _defaultCenter : LatLng(i.lat, i.lng);
    _address = i?.address ?? '';
    if (i == null) {
      // Coba ambil GPS otomatis; kalau gagal biarkan di Surabaya.
      WidgetsBinding.instance.addPostFrameCallback((_) => _useGps(silent: true));
    }
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _useGps({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final p = await currentGpsPosition();
      _moveTo(p, 17);
      await _reverse();
    } on LocationException catch (e) {
      if (!silent && mounted) snack(context, e.message);
    } catch (_) {
      if (!silent && mounted) snack(context, 'Gagal mendapatkan lokasi saat ini.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _moveTo(LatLng p, double zoom) {
    _center = p;
    _map.move(p, zoom);
  }

  void _scheduleReverse() {
    _reverseTimer?.cancel();
    _reverseTimer = Timer(const Duration(milliseconds: 600), _reverse);
  }

  Future<void> _reverse() async {
    if (!mounted) return;
    setState(() => _loadingAddress = true);
    final target = _center;
    try {
      final a = await GeoService.reverse(target.latitude, target.longitude);
      if (mounted && target == _center) setState(() => _address = a);
    } catch (_) {
      if (mounted && target == _center) {
        setState(() => _address =
            '${target.latitude.toStringAsFixed(5)}, ${target.longitude.toStringAsFixed(5)}');
      }
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  void _onQueryChanged(String q) {
    _searchTimer?.cancel();
    if (q.trim().length < 3) {
      setState(() {
        _results = [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 700), () async {
      setState(() {
        _searching = true;
        _searchError = null;
      });
      try {
        final r = await GeoService.search(q.trim());
        if (mounted) setState(() => _results = r);
      } catch (_) {
        if (mounted) {
          setState(() {
            _results = [];
            _searchError = 'Gagal mencari. Periksa koneksi internet.';
          });
        }
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _pickResult(PickedLocation r) {
    _searchFocus.unfocus();
    setState(() {
      _results = [];
      _searchCtrl.text = r.address.split(',').first;
      _address = r.address;
    });
    _moveTo(LatLng(r.lat, r.lng), 17);
  }

  void _confirm() {
    Navigator.pop(
      context,
      PickedLocation(
        lat: _center.latitude,
        lng: _center.longitude,
        address: _address.isEmpty
            ? '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}'
            : _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPanel = _searching || _searchError != null || _results.isNotEmpty;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              onPositionChanged: (camera, hasGesture) {
                _center = camera.center;
                if (hasGesture) _scheduleReverse();
              },
              onTap: (_, __) => _searchFocus.unfocus(),
            ),
            children: [
              TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgentPackage),
            ],
          ),
          // Pin tetap di tengah layar; ujung pin = titik terpilih.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: const Icon(Icons.location_on, size: 48, color: Color(0xFFDC2626)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(14),
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            textInputAction: TextInputAction.search,
                            onChanged: _onQueryChanged,
                            decoration: InputDecoration(
                              hintText: 'Cari alamat atau tempat…',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchCtrl.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _onQueryChanged('');
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showPanel)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : _searchError != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(_searchError!),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: _results.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (_, i) => ListTile(
                                        leading: const Icon(Icons.place_outlined),
                                        title: Text(
                                          _results[i].address,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        onTap: () => _pickResult(_results[i]),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton.small(
              heroTag: 'gps',
              backgroundColor: Colors.white,
              foregroundColor: kPrimary,
              onPressed: _locating ? null : _useGps,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lokasi terpilih',
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place, color: kPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadingAddress
                                ? 'Mencari alamat…'
                                : (_address.isEmpty ? 'Geser peta untuk memilih' : _address),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loadingAddress ? null : _confirm,
                        child: const Text('Pilih lokasi ini'),
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
