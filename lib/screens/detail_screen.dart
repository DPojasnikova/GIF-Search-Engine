import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gif_model.dart';

class DetailScreen extends StatelessWidget {
  final Gif gif;

  const DetailScreen({super.key, required this.gif});

  @override
  Widget build(BuildContext context) {
    final title = gif.title.isEmpty ? 'Untitled' : gif.title;

    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final image = buildImage();
            final info = buildInfo(context, title);

            if (orientation == Orientation.portrait) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [image, const SizedBox(height: 16), info],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Center(child: image)),
                  const SizedBox(width: 16),
                  Expanded(child: SingleChildScrollView(child: info)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        gif.originalUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stack) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('Could not load the gif')),
          );
        },
      ),
    );
  }

  Widget buildInfo(BuildContext context, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (gif.username.isNotEmpty) Text('Author: ${gif.username}'),
        if (gif.rating.isNotEmpty) Text('Rating: ${gif.rating.toUpperCase()}'),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.link),
          label: const Text('Copy link'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: gif.pageUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copied')),
            );
          },
        ),
      ],
    );
  }
}
