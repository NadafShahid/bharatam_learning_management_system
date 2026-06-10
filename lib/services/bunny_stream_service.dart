import 'dart:convert';
import 'dart:io';

class BunnyStreamService {
  final String libraryId = "676379";
  final String accessKey = "e7fe790c-05ab-4cc7-8aa0fe8cefb6-b71c-4c12";
  final String pullZoneUrl = "vz-5549fe19-18c.b-cdn.net";

  /// Uploads a video file to Bunny Stream.
  /// Returns a Map with 'bunnyVideoId' and 'storageUrl' if successful, null otherwise.
  Future<Map<String, String>?> uploadVideo({
    required File file,
    required String title,
    required Function(double progress) onProgress,
  }) async {
    final client = HttpClient();
    try {
      // Step 1: Create Video Placeholder
      final createUrl = Uri.parse('https://video.bunnycdn.com/library/$libraryId/videos');
      final createRequest = await client.postUrl(createUrl);
      createRequest.headers.set('AccessKey', accessKey);
      createRequest.headers.set('Content-Type', 'application/json');
      createRequest.headers.set('accept', 'application/json');
      
      final payload = utf8.encode(jsonEncode({'title': title}));
      createRequest.contentLength = payload.length;
      createRequest.add(payload);
      final createResponse = await createRequest.close();
      
      if (createResponse.statusCode != 200) {
        throw Exception('Failed to create video placeholder. Status: ${createResponse.statusCode}');
      }
      
      final createResponseBody = await createResponse.transform(utf8.decoder).join();
      final createData = jsonDecode(createResponseBody);
      final String videoId = createData['guid'];

      // Step 2: Upload Video File Binary Data
      final uploadUrl = Uri.parse('https://video.bunnycdn.com/library/$libraryId/videos/$videoId');
      final uploadRequest = await client.putUrl(uploadUrl);
      uploadRequest.headers.set('AccessKey', accessKey);
      uploadRequest.headers.set('Content-Type', 'application/octet-stream');

      final int fileLength = await file.length();
      uploadRequest.contentLength = fileLength;

      // Pipe file chunk-by-chunk to monitor upload progress
      final fileStream = file.openRead();
      int bytesSent = 0;

      await for (final chunk in fileStream) {
        uploadRequest.add(chunk);
        bytesSent += chunk.length;
        onProgress(bytesSent / fileLength);
      }

      final uploadResponse = await uploadRequest.close();
      if (uploadResponse.statusCode != 200) {
        throw Exception('Failed to upload video binary. Status: ${uploadResponse.statusCode}');
      }

      // Step 3: Construct the final Playback URL
      final playbackUrl = 'https://$pullZoneUrl/$videoId/playlist.m3u8';

      return {
        'bunnyVideoId': videoId,
        'storageUrl': playbackUrl,
      };
    } catch (e) {
      print('Bunny Stream Upload Error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Fetches video length in seconds from Bunny Stream API.
  /// Returns the length in seconds, or 0 if failed.
  Future<int> getVideoLength(String videoId) async {
    final client = HttpClient();
    try {
      final url = Uri.parse('https://video.bunnycdn.com/library/$libraryId/videos/$videoId');
      final request = await client.getUrl(url);
      request.headers.set('AccessKey', accessKey);
      request.headers.set('accept', 'application/json');
      
      final response = await request.close();
      if (response.statusCode != 200) {
        return 0;
      }
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody);
      // 'length' is in seconds
      return data['length'] as int? ?? 0;
    } catch (e) {
      print('Bunny Stream Get Video Length Error: $e');
      return 0;
    } finally {
      client.close();
    }
  }
}
