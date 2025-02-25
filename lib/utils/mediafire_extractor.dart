import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class MediafireExtractor {
  static Future<String?> extractDirectUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final downloadButton = document.querySelector('a#downloadButton');
        return downloadButton?.attributes['href'];
      }
    } catch (e) {
      print('Mediafire extraction error: $e');
    }
    return null;
  }

  static bool isMediafireUrl(String url) {
    return url.contains('mediafire.com');
  }
}
