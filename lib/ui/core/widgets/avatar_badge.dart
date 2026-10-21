import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants.dart';

class AvatarBadge extends StatelessWidget {
  final String avatar;
  final String? photoUrl;
  final Uint8List? imageBytes;
  final String? baseUrl;
  final double size;
  final double fontSize;

  const AvatarBadge({
    super.key,
    required this.avatar,
    this.photoUrl,
    this.imageBytes,
    this.baseUrl,
    this.size = 54,
    this.fontSize = 28,
  });

  String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) {
      return url;
    }
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      final base = baseUrl!.replaceAll(RegExp(r'/+$'), '');
      final path = url.startsWith('/') ? url : '/$url';
      return '$base$path';
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('null')) {
        final path = url.startsWith('/') ? url : '/$url';
        return '$origin$path';
      }
    }
    final path = url.startsWith('/') ? url : '/$url';
    return 'http://127.0.0.1:8080$path';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emoji = AppConstants.getAvatarEmoji(avatar);

    Widget fallbackEmoji() {
      return Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: fontSize),
        ),
      );
    }

    Widget content = fallbackEmoji();

    if (imageBytes != null && imageBytes!.isNotEmpty) {
      content = Image.memory(
        imageBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => fallbackEmoji(),
      );
    } else if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      final rawUrl = photoUrl!.trim();
      if (rawUrl.startsWith('data:image')) {
        try {
          final b64 = rawUrl.contains(',') ? rawUrl.split(',')[1] : rawUrl;
          final bytes = base64Decode(b64);
          content = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => fallbackEmoji(),
          );
        } catch (_) {
          content = fallbackEmoji();
        }
      } else {
        final fullUrl = _resolveUrl(rawUrl);
        content = Image.network(
          fullUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => fallbackEmoji(),
        );
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: content,
      ),
    );
  }
}
