/// BunnyStorageHelper
///
/// Central helper for resolving BunnyCDN Storage URLs.
///
/// Problem:
///   The storage zone "bhartamproject" has no pull zone connected.
///   Old URLs stored in Firebase use "bhartamproject.b-cdn.net" which is
///   suspended/non-existent and causes "Domain suspended" errors.
///
/// Solution:
///   Rewrite any broken pull-zone URL to the direct BunnyCDN Storage API
///   endpoint (storage.bunnycdn.com) and authenticate every request with
///   the Storage Access Key header.  Flutter's Image.network() accepts
///   custom headers, so this works transparently in the app.
///
///   Stream videos (vz-5549fe19-18c.b-cdn.net) are NOT touched — they
///   have their own working CDN pull zone.
class BunnyStorageHelper {
  // ── Storage Zone credentials ─────────────────────────────────────────────
  static const String _storageZoneName = 'bhartamproject';
  static const String _storageAccessKey =
      'ee76b2b6-6b5a-418c-9afbe57e1282-1cfa-42d7';

  // The direct storage endpoint (always works with access key)
  static const String _storageBase =
      'https://storage.bunnycdn.com/$_storageZoneName';

  // The broken pull-zone hostname that is currently suspended
  static const String _brokenPullZoneHost = 'bhartamproject.b-cdn.net';

  // ── Stream CDN hostname (already correct — do NOT rewrite) ───────────────
  static const String _streamCdnHost = 'vz-5549fe19-18c.b-cdn.net';

  /// HTTP headers required to access private BunnyCDN Storage files.
  static const Map<String, String> storageHeaders = {
    'AccessKey': _storageAccessKey,
  };

  /// Returns true if [url] points to BunnyCDN Storage (and may need fixing).
  /// Stream CDN URLs are excluded — they work fine without auth.
  static bool isStorageUrl(String url) {
    if (url.isEmpty) return false;
    if (url.contains(_streamCdnHost)) return false; // stream CDN — leave alone
    return url.contains(_brokenPullZoneHost) ||
        url.contains('storage.bunnycdn.com/$_storageZoneName');
  }

  /// Converts any broken/old pull-zone URL to the working storage API URL.
  ///
  /// Examples:
  ///   Input : https://bhartamproject.b-cdn.net/bharatm_library/thumb.jpg
  ///   Output: https://storage.bunnycdn.com/bhartamproject/bharatm_library/thumb.jpg
  ///
  ///   Input : https://storage.bunnycdn.com/bhartamproject/... (already correct)
  ///   Output: same URL unchanged
  ///
  ///   Input : https://vz-5549fe19-18c.b-cdn.net/... (stream video)
  ///   Output: same URL unchanged
  static String fixUrl(String url) {
    if (url.isEmpty) return url;

    // Already a direct storage URL — nothing to fix
    if (url.contains('storage.bunnycdn.com/$_storageZoneName')) return url;

    // Rewrite old suspended pull-zone URL → direct storage API URL
    if (url.contains(_brokenPullZoneHost)) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        // uri.path already starts with '/', e.g. /bharatm_library/thumb.jpg
        return '$_storageBase${uri.path}';
      }
    }

    // Unknown URL — return as-is
    return url;
  }

  /// Returns the correct URL and the headers needed to load it.
  ///
  /// Use this when building Image.network() or any HTTP request for a
  /// BunnyCDN Storage file.
  static ({String url, Map<String, String> headers}) resolve(String rawUrl) {
    final fixed = fixUrl(rawUrl);
    final needsAuth = fixed.contains('storage.bunnycdn.com/$_storageZoneName');
    return (
      url: fixed,
      headers: needsAuth ? storageHeaders : const {},
    );
  }

  /// Generates the correct direct-storage public URL for a newly uploaded file.
  ///
  /// [path] is the destination path inside the storage zone,
  /// e.g. 'bharatm_library/thumbnails/thumb.jpg'
  static String buildUploadUrl(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$_storageBase/$cleanPath';
  }
}
