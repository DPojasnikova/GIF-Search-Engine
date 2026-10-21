import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_search_engine/config.dart';
import 'package:gif_search_engine/gif_model.dart';
import 'package:gif_search_engine/giphy_api.dart';
import 'package:gif_search_engine/screens/detail_screen.dart';
import 'package:gif_search_engine/screens/search_screen.dart';

class FakeGiphyApi extends GiphyApi {
  final List<String> queries = [];
  final List<int> offsets = [];

  Future<List<Gif>> Function(String query, int offset)? handler;

  @override
  Future<List<Gif>> loadGifs(String query, int offset) {
    queries.add(query);
    offsets.add(offset);
    if (handler != null) {
      return handler!(query, offset);
    }
    return Future.value(makeGifs(pageSize, offset));
  }
}

List<Gif> makeGifs(int count, int start) {
  return List.generate(count, (i) {
    final number = start + i;
    return Gif(
      id: 'id$number',
      title: 'Gif $number',
      previewUrl: 'https://example.com/small$number.gif',
      originalUrl: 'https://example.com/big$number.gif',
      username: 'user$number',
      rating: 'g',
      pageUrl: 'https://giphy.com/gifs/$number',
    );
  });
}

Future<void> openScreen(WidgetTester tester, FakeGiphyApi api) async {
  await tester.pumpWidget(MaterialApp(home: SearchScreen(api: api)));
  await tester.pump();
}

int columnCount(WidgetTester tester) {
  final grid = tester.widget<GridView>(find.byType(GridView));
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  return delegate.crossAxisCount;
}

void main() {
  group('Auto search', () {
    testWidgets('loads trending gifs when the screen opens', (tester) async {
      final api = FakeGiphyApi();
      await openScreen(tester, api);

      expect(api.queries, ['']);
      expect(api.offsets, [0]);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('does not search while the user is still typing',
        (tester) async {
      final api = FakeGiphyApi();
      await openScreen(tester, api);

      await tester.enterText(find.byType(TextField), 'ca');
      await tester.pump(const Duration(milliseconds: searchDelayMs - 200));
      await tester.enterText(find.byType(TextField), 'cat');
      await tester.pump(const Duration(milliseconds: searchDelayMs - 200));

      expect(api.queries, ['']);
    });

    testWidgets('searches once after the user stops typing', (tester) async {
      final api = FakeGiphyApi();
      await openScreen(tester, api);

      await tester.enterText(find.byType(TextField), 'c');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'cat');
      await tester.pump(const Duration(milliseconds: searchDelayMs + 50));

      expect(api.queries, ['', 'cat']);
      expect(api.offsets.last, 0);
    });

    testWidgets('the clear button goes back to trending', (tester) async {
      final api = FakeGiphyApi();
      await openScreen(tester, api);

      await tester.enterText(find.byType(TextField), 'cat');
      await tester.pump(const Duration(milliseconds: searchDelayMs + 50));
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump(const Duration(milliseconds: searchDelayMs + 50));

      expect(api.queries, ['', 'cat', '']);
    });
  });

  group('Loading indicators', () {
    testWidgets('shows a spinner while the first page is loading',
        (tester) async {
      final api = FakeGiphyApi();
      final completer = Completer<List<Gif>>();
      api.handler = (query, offset) => completer.future;

      await openScreen(tester, api);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      completer.complete(makeGifs(3, 0));
      await tester.pump();
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('shows a spinner while the next page is loading',
        (tester) async {
      final api = FakeGiphyApi();
      await openScreen(tester, api);

      final completer = Completer<List<Gif>>();
      api.handler = (query, offset) => completer.future;

      await tester.drag(find.byType(GridView), const Offset(0, -5000));
      await tester.pump();

      await tester.drag(find.byType(GridView), const Offset(0, -5000));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('Pagination', () {
    testWidgets('loads the next page when the user scrolls down',
        (tester) async {
      final api = FakeGiphyApi();
      await openScreen(tester, api);
      expect(api.offsets, [0]);

      await tester.drag(find.byType(GridView), const Offset(0, -5000));
      await tester.pump();

      expect(api.offsets, [0, pageSize]);
    });

    testWidgets('stops loading when the server has no more gifs',
        (tester) async {
      final api = FakeGiphyApi();
      api.handler = (query, offset) async => makeGifs(5, 0);
      await openScreen(tester, api);

      await tester.drag(find.byType(GridView), const Offset(0, -5000));
      await tester.pump();

      expect(api.offsets, [0]);
    });
  });

  group('Error handling', () {
    testWidgets('shows the error text and a Retry button', (tester) async {
      final api = FakeGiphyApi();
      api.handler = (query, offset) async {
        throw GiphyException('No internet connection');
      };
      await openScreen(tester, api);

      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('Retry loads the gifs again', (tester) async {
      final api = FakeGiphyApi();
      api.handler = (query, offset) async {
        throw GiphyException('No internet connection');
      };
      await openScreen(tester, api);

      api.handler = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(find.text('No internet connection'), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('shows a message when nothing is found', (tester) async {
      final api = FakeGiphyApi();
      api.handler = (query, offset) async => [];
      await openScreen(tester, api);

      expect(find.text('Nothing found'), findsOneWidget);
    });

    testWidgets('an error on the next page keeps the gifs on the screen',
        (tester) async {
      final api = FakeGiphyApi();
      await openScreen(tester, api);

      api.handler = (query, offset) async {
        throw GiphyException('Server error (500)');
      };
      await tester.drag(find.byType(GridView), const Offset(0, -5000));
      await tester.pump();
      await tester.drag(find.byType(GridView), const Offset(0, -5000));
      await tester.pump();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Grid and orientation', () {
    testWidgets('portrait has 2 columns', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await openScreen(tester, FakeGiphyApi());
      expect(columnCount(tester), 2);
    });

    testWidgets('landscape has more columns', (tester) async {
      tester.view.physicalSize = const Size(2400, 1080);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await openScreen(tester, FakeGiphyApi());
      expect(columnCount(tester), greaterThan(2));
    });
  });

  group('Floating search field', () {
    double searchOpacity(WidgetTester tester) {
      return tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity;
    }

    testWidgets('hides when scrolling down and shows when scrolling up',
        (tester) async {
      await openScreen(tester, FakeGiphyApi());
      expect(searchOpacity(tester), 1);

      await tester.drag(find.byType(GridView), const Offset(0, -400));
      await tester.pump();
      expect(searchOpacity(tester), 0);

      await tester.drag(find.byType(GridView), const Offset(0, 200));
      await tester.pump();
      expect(searchOpacity(tester), 1);
    });
  });

  group('Navigation', () {
    testWidgets('tapping a gif opens the detail screen', (tester) async {
      await openScreen(tester, FakeGiphyApi());

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.byType(DetailScreen), findsOneWidget);
      expect(find.text('Gif 0'), findsWidgets);
      expect(find.text('Author: user0'), findsOneWidget);
    });

    testWidgets('the back button returns to the grid', (tester) async {
      await openScreen(tester, FakeGiphyApi());

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(DetailScreen), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
    });
  });
}
