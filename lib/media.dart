import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'ui.dart';

final _picker = ImagePicker();

/// Pilih foto dari kamera atau galeri. Hasilnya bytes (aman untuk Android & web).
Future<List<Uint8List>> pickPhotos(BuildContext context) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (src == null) return [];
  try {
    if (src == ImageSource.camera) {
      final x = await _picker.pickImage(source: src, maxWidth: 1280, imageQuality: 80);
      return x == null ? [] : [await x.readAsBytes()];
    }
    final xs = await _picker.pickMultiImage(maxWidth: 1280, imageQuality: 80);
    return [for (final x in xs) await x.readAsBytes()];
  } catch (_) {
    if (context.mounted) snack(context, 'Tidak bisa mengakses kamera/galeri.');
    return [];
  }
}

void openPhotoViewer(BuildContext context, List<Uint8List> photos, int index) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: index),
        itemCount: photos.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: Image.memory(photos[i])),
        ),
      ),
    ),
  ));
}

/// Deretan thumbnail foto. Jika [onRemove] diisi, tampil tombol hapus.
class PhotoThumbs extends StatelessWidget {
  const PhotoThumbs({super.key, required this.photos, this.onRemove, this.size = 84});
  final List<Uint8List> photos;
  final void Function(int index)? onRemove;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Stack(
          children: [
            GestureDetector(
              onTap: () => openPhotoViewer(context, photos, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(photos[i], width: size, height: size, fit: BoxFit.cover),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove!(i),
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

typedef ReportInput = ({String note, List<Uint8List> photos});

/// Bottom sheet untuk lapor progres / bukti penyelesaian (catatan + foto).
Future<ReportInput?> showReportSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required bool requirePhoto,
}) {
  return showModalBottomSheet<ReportInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ReportSheet(title: title, hint: hint, requirePhoto: requirePhoto),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.title, required this.hint, required this.requirePhoto});
  final String title;
  final String hint;
  final bool requirePhoto;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _note = TextEditingController();
  final List<Uint8List> _photos = [];
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final p = await pickPhotos(context);
    if (p.isEmpty) return;
    setState(() {
      _photos.addAll(p);
      if (_photos.length > 6) _photos.removeRange(6, _photos.length);
      _error = null;
    });
  }

  void _submit() {
    final note = _note.text.trim();
    if (widget.requirePhoto && _photos.isEmpty) {
      setState(() => _error = 'Foto bukti wajib diisi (minimal 1).');
      return;
    }
    if (note.isEmpty && _photos.isEmpty) {
      setState(() => _error = 'Isi catatan atau tambahkan foto.');
      return;
    }
    Navigator.pop(context, (note: note, photos: List<Uint8List>.of(_photos)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(hintText: widget.hint),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Foto bukti', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text(
                  widget.requirePhoto ? '(wajib)' : '(opsional)',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_photos.isNotEmpty) ...[
              PhotoThumbs(
                photos: _photos,
                onRemove: (i) => setState(() => _photos.removeAt(i)),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _photos.length >= 6 ? null : _add,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(_photos.isEmpty ? 'Tambah foto' : 'Tambah lagi (${_photos.length}/6)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _submit, child: const Text('Kirim')),
            ),
          ],
        ),
      ),
    );
  }
}
