import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'gif_model.dart';

// An error with a readable message that can be shown to the user
class GiphyException implements Exception {
  final String message;
  GiphyException(this.message);

  @override
  String toString() => message;
}

class GiphyApi {
  // The client can be replaced in tests
  final http.Client client;

  GiphyApi({http.Client? client}) : client = client ?? http.Client();

  // If the query is empty we load trending gifs, otherwise we search
  Future<List<Gif>> loadGifs(String query, int offset) async {
    final String path = query.isEmpty ? '/v1/gifs/trending' : '/v1/gifs/search';

    final Map<String, String> params = {
      'api_key': giphyApiKey,
      'limit': pageSize.toString(),
      'offset': offset.toString(),
    };
    if (query.isNotEmpty) {
      params['q'] = query;
    }

    final uri = Uri.https('api.giphy.com', path, params);

    http.Response response;
    try {
      response = await client.get(uri).timeout(const Duration(seconds: 15));
    } on SocketException {
      throw GiphyException('No internet connection');
    } on http.ClientException {
      throw GiphyException('No internet connection');
    } on Exception {
      throw GiphyException('The server is not responding. Try again later');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw GiphyException('Invalid Giphy API key');
    }
    if (response.statusCode == 429) {
      throw GiphyException('Too many requests. Please wait a bit');
    }
    if (response.statusCode != 200) {
      throw GiphyException('Server error (${response.statusCode})');
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>;
      return list
          .map((item) => Gif.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw GiphyException('Could not read the server response');
    }
  }
}
