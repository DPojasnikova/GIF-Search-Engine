import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_search_engine/gif_model.dart';
import 'package:gif_search_engine/giphy_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String fakeGifJson = '''
{
  "id": "abc123",
  "title": "funny cat",
  "username": "catlover",
  "rating": "g",
  "url": "https://giphy.com/gifs/abc123",
  "images": {
    "fixed_width": {"url": "https://media.giphy.com/small.gif"},
    "original": {"url": "https://media.giphy.com/big.gif"}
  }
}
''';

void main() {
  group('Gif.fromJson', () {
    test('reads all fields', () {
      final gif = Gif.fromJson(jsonDecode(fakeGifJson));
      expect(gif.id, 'abc123');
      expect(gif.title, 'funny cat');
      expect(gif.previewUrl, 'https://media.giphy.com/small.gif');
      expect(gif.originalUrl, 'https://media.giphy.com/big.gif');
      expect(gif.username, 'catlover');
    });

    test('username equal to null becomes an empty string', () {
      final json = jsonDecode(fakeGifJson) as Map<String, dynamic>;
      json['username'] = null;
      expect(Gif.fromJson(json).username, '');
    });
  });

  group('GiphyApi.loadGifs', () {
    test('empty query goes to trending', () async {
      Uri? usedUri;
      final client = MockClient((request) async {
        usedUri = request.url;
        return http.Response('{"data": [$fakeGifJson]}', 200);
      });

      final gifs = await GiphyApi(client: client).loadGifs('', 0);

      expect(usedUri!.path, '/v1/gifs/trending');
      expect(gifs.length, 1);
    });

    test('non-empty query goes to search with q and offset', () async {
      Uri? usedUri;
      final client = MockClient((request) async {
        usedUri = request.url;
        return http.Response('{"data": []}', 200);
      });

      await GiphyApi(client: client).loadGifs('cat', 24);

      expect(usedUri!.path, '/v1/gifs/search');
      expect(usedUri!.queryParameters['q'], 'cat');
      expect(usedUri!.queryParameters['offset'], '24');
    });

    test('no internet gives a readable error', () async {
      final client = MockClient((request) async {
        throw const SocketException('no internet');
      });

      expect(
        () => GiphyApi(client: client).loadGifs('cat', 0),
        throwsA(isA<GiphyException>()),
      );
    });

    test('status 403 gives an error about the API key', () async {
      final client = MockClient((request) async {
        return http.Response('{}', 403);
      });

      expect(
        () => GiphyApi(client: client).loadGifs('cat', 0),
        throwsA(
          predicate((e) => e is GiphyException && e.message.contains('key')),
        ),
      );
    });

    test('broken JSON gives an error instead of a crash', () async {
      final client = MockClient((request) async {
        return http.Response('not json', 200);
      });

      expect(
        () => GiphyApi(client: client).loadGifs('cat', 0),
        throwsA(isA<GiphyException>()),
      );
    });
  });
}
