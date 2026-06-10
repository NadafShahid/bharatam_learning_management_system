import 'package:flutter/material.dart';
import '../services/bunny_storage_helper.dart';

/// A drop-in replacement for Image.network that transparently handles
/// BunnyCDN Storage authentication.
///
/// • If [imageUrl] points to a BunnyCDN Storage file (old pull-zone URL or
///   direct storage URL), it rewrites the URL and injects the AccessKey
///   header so the image loads correctly even without a CDN pull zone.
///
/// • If [imageUrl] is a BunnyCDN Stream CDN URL (vz-*.b-cdn.net), or any
///   other URL, it is passed through untouched.
///
/// Usage — replace any:
///   Image.network(someUrl, fit: BoxFit.cover)
/// with:
///   BunnyStorageImage(imageUrl: someUrl, fit: BoxFit.cover)
class BunnyStorageImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final AlignmentGeometry alignment;

  const BunnyStorageImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.loadingBuilder,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorBuilder?.call(context, Exception('Empty URL'), null) ??
          const SizedBox.shrink();
    }

    final String fixedUrl = BunnyStorageHelper.fixUrl(imageUrl);
    final Map<String, String> hdrs =
        BunnyStorageHelper.isStorageUrl(imageUrl)
            ? BunnyStorageHelper.storageHeaders
            : const {};

    // Debug: trace raw → fixed URL for thumbnails
    debugPrint('[BunnyImg] RAW  : $imageUrl');
    debugPrint('[BunnyImg] FIXED: $fixedUrl | auth=${hdrs.isNotEmpty}');

    return Image.network(
      fixedUrl,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      headers: hdrs,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}

/// Factory function that returns a [NetworkImage] with BunnyCDN Storage
/// auth headers already injected.
///
/// Use this wherever an [ImageProvider] is expected (e.g. [DecorationImage]).
///
/// Usage — replace any:
///   NetworkImage(someUrl)
/// with:
///   bunnyStorageNetworkImage(someUrl)
NetworkImage bunnyStorageNetworkImage(String rawUrl, {double scale = 1.0}) {
  final String fixedUrl = BunnyStorageHelper.fixUrl(rawUrl);
  final Map<String, String>? hdrs =
      BunnyStorageHelper.isStorageUrl(rawUrl)
          ? BunnyStorageHelper.storageHeaders
          : null;

  return NetworkImage(fixedUrl, headers: hdrs, scale: scale);
}
