import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'face_reference_vault.dart';

/// Returns a bounded decode width for a small on-screen encrypted-photo preview.
/// Keep the source aspect ratio by constraining one dimension only.
int facePhotoPreviewCacheWidth({
  required double width,
  required double height,
  required double devicePixelRatio,
}) {
  final longestEdge = width > height ? width : height;
  return (longestEdge * devicePixelRatio).round().clamp(1, 2048).toInt();
}

/// Shows an app-private encrypted face photo only after local vault decryption.
class EncryptedFacePhotoPreview extends StatefulWidget {
  const EncryptedFacePhotoPreview({
    super.key,
    required this.path,
    required this.accountScope,
    required this.width,
    required this.height,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
    @visibleForTesting this.photoLoader,
  });

  final String path;
  final String accountScope;
  final double width;
  final double height;
  final String semanticLabel;
  final BoxFit fit;

  @visibleForTesting
  final Future<Uint8List> Function(String path, String accountScope)? photoLoader;

  @override
  State<EncryptedFacePhotoPreview> createState() =>
      _EncryptedFacePhotoPreviewState();
}

class _EncryptedFacePhotoPreviewState extends State<EncryptedFacePhotoPreview> {
  late Future<Uint8List> _photo;

  @override
  void initState() {
    super.initState();
    _photo = _load();
  }

  @override
  void didUpdateWidget(covariant EncryptedFacePhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.accountScope != widget.accountScope) {
      _photo = _load();
    }
  }

  Future<Uint8List> _load() async {
    final testLoader = widget.photoLoader;
    if (testLoader != null) return testLoader(widget.path, widget.accountScope);
    return (await FaceReferenceVault.openOnDevice(
      accountScope: widget.accountScope,
    )).decryptPhoto(widget.path);
  }

  Widget _placeholder(IconData icon, {String? label}) => Semantics(
        label: label ?? widget.semanticLabel,
        image: true,
        child: ColoredBox(
          color: const Color(0xFF232A38),
          child: Center(child: Icon(icon, color: Colors.white70)),
        ),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        height: widget.height,
        // A FutureBuilder retains its last snapshot while its future changes.
        // Key it by the encrypted object and workspace so a workspace switch
        // cannot briefly show the previous user's decrypted image.
        child: FutureBuilder<Uint8List>(
          key: ValueKey('${widget.accountScope}:${widget.path}'),
          future: _photo,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _placeholder(
                Icons.lock_outline,
                label: '${widget.semanticLabel}, unavailable',
              );
            }
            if (!snapshot.hasData) {
              return _placeholder(Icons.hourglass_top_rounded);
            }
            final cacheWidth = facePhotoPreviewCacheWidth(
              width: widget.width,
              height: widget.height,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            return Image.memory(
              snapshot.data!,
              width: widget.width,
              height: widget.height,
              cacheWidth: cacheWidth,
              fit: widget.fit,
              semanticLabel: widget.semanticLabel,
              errorBuilder: (_, __, ___) => _placeholder(
                Icons.broken_image_outlined,
                label: '${widget.semanticLabel}, image damaged',
              ),
            );
          },
        ),
      );
}
