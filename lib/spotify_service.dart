import 'dart:convert';
import 'package:http/http.dart' as http;
import 'home_screen.dart';

class SpotifyService {
  static const String _clientId     = '1b53bd35f56f45d4b4ea1cc0757b86d1';
  static const String _clientSecret = 'ef901563146e4c7497b520c3dc2d0e46';

  String?   _accessToken;
  DateTime? _tokenExpiry;

  // ── Step 1: Get access token ──────────────────────────────────────────────
  Future<void> _authenticate() async {
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data   = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String;
      _tokenExpiry = DateTime.now()
          .add(Duration(seconds: (data['expires_in'] as int) - 60));
    } else {
      throw Exception('Auth failed (${response.statusCode}): ${response.body}');
    }
  }

  bool get _tokenValid =>
      _accessToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  // ── Step 2: Search tracks ─────────────────────────────────────────────────
  Future<List<MusicTrack>> searchTracks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    if (!_tokenValid) await _authenticate();

    // Uri.replace with queryParameters handles all encoding correctly in Dart
    final uri = Uri.parse('https://api.spotify.com/v1/search').replace(
      queryParameters: {
        'q':     q,
        'type':  'track',
        'limit': '10',
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    ).timeout(const Duration(seconds: 15));

    // Token expired — refresh and retry once
    if (response.statusCode == 401) {
      _accessToken = null;
      await _authenticate();
      return searchTracks(q);
    }

    if (response.statusCode == 200) {
      final data  = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['tracks']['items'] as List<dynamic>;

      return items.map<MusicTrack>((item) {
        final images     = (item['album']['images'] as List?) ?? [];
        final artUrl     = images.isNotEmpty ? images[0]['url'] as String : '';
        final colorIndex = (item['name'] as String).length % 6;

        return MusicTrack(
          id:            item['id']   as String,
          title:         item['name'] as String,
          artist:        (item['artists'] as List).isNotEmpty
                           ? item['artists'][0]['name'] as String
                           : 'Unknown Artist',
          albumArt:      artUrl,
          dominantColor: BT.pastelAt(colorIndex),
        );
      }).toList();
    }

    throw Exception(
      'Spotify error (${response.statusCode}): ${response.body}',
    );
  }
}