import 'dart:io';
import 'bunny_storage_helper.dart';

class BunnyStorageService {
  final String accessKey = "ee76b2b6-6b5a-418c-9afbe57e1282-1cfa-42d7";
  final String storageZoneName = "bhartamproject";

  // Direct storage API endpoint — used for both upload and public access.
  // NOTE: The storage zone "bhartamproject" has no CDN pull zone connected,
  // so we use the direct storage.bunnycdn.com endpoint authenticated with
  // the AccessKey header. BunnyStorageHelper / BunnyStorageImage handle
  // injecting this header whenever an image is displayed in the app.
  String get storageEndpoint => "https://storage.bunnycdn.com/$storageZoneName";

  /// Uploads a file to Bunny Storage.
  /// [path] is the destination path in the storage zone,
  /// e.g., 'bharatm_library/thumbnails/my_thumb.jpg'.
  /// Returns the public storage URL of the uploaded file if successful, null otherwise.
  Future<String?> uploadFile({
    required File file,
    required String path,
    Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final uploadUrl = Uri.parse('$storageEndpoint/$cleanPath');
      final request = await client.putUrl(uploadUrl);
      request.headers.set('AccessKey', accessKey);
      request.headers.set('Content-Type', 'application/octet-stream');

      final int fileLength = await file.length();
      request.contentLength = fileLength;

      if (onProgress != null) {
        final fileStream = file.openRead();
        int bytesSent = 0;

        await for (final chunk in fileStream) {
          request.add(chunk);
          bytesSent += chunk.length;
          onProgress(bytesSent / fileLength);
        }
      } else {
        await request.addStream(file.openRead());
      }

      final response = await request.close();
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
            'Failed to upload file to Bunny Storage. Status: ${response.statusCode}');
      }

      // Return the direct storage URL (authenticated via AccessKey header in the app)
      final publicUrl = BunnyStorageHelper.buildUploadUrl(cleanPath);
      return publicUrl;
    } catch (e) {
      print('Bunny Storage Upload Error: $e');
      return null;
    } finally {
      client.close();
    }
  }
}
