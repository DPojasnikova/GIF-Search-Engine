import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_search_engine/gif_model.dart';
import 'package:gif_search_engine/screens/detail_screen.dart';

Gif makeGif({String title = 'Funny cat', String username = 'catlover'}) {
  return Gif(
    id: 'abc123',
    title: title,
    previewUrl: 'https://example.com/small.gif',
    originalUrl: 'https://example.com/big.gif',
    username: username,
    rating: 'g',
    pageUrl: 'https://giphy.com/gifs/abc123',
  );
}

void main() {
  testWidgets('shows title, author and rating', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DetailScreen(gif: makeGif())));

    expect(find.text('Funny cat'), findsWidgets);
    expect(find.text('Author: catlover'), findsOneWidget);
    expect(find.text('Rating: G'), findsOneWidget);
  });

  testWidgets('shows "Untitled" when the gif has no title', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: DetailScreen(gif: makeGif(title: ''))));

    expect(find.text('Untitled'), findsWidgets);
  });

  testWidgets('hides the author line when there is no author',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: DetailScreen(gif: makeGif(username: ''))));

    expect(find.textContaining('Author'), findsNothing);
  });

  testWidgets('the copy button shows a confirmation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DetailScreen(gif: makeGif())));

    await tester.tap(find.text('Copy link'));
    await tester.pump();

    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('works in landscape mode', (tester) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: DetailScreen(gif: makeGif())));

    expect(find.text('Copy link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
