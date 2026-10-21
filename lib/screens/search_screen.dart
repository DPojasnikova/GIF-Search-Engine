import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config.dart';
import '../gif_model.dart';
import '../giphy_api.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final GiphyApi? api;

  const SearchScreen({super.key, this.api});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final GiphyApi api = widget.api ?? GiphyApi();
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  Timer? searchTimer;

  List<Gif> gifs = [];
  String query = '';
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? errorText;
  String? loadMoreError;
  bool showSearchBar = true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(onScroll);
    loadFirstPage();
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void onSearchChanged(String text) {
    searchTimer?.cancel();
    searchTimer = Timer(const Duration(milliseconds: searchDelayMs), () {
      final newQuery = text.trim();
      if (newQuery != query) {
        query = newQuery;
        loadFirstPage();
      }
    });
  }

  Future<void> loadFirstPage() async {
    final requestQuery = query;
    setState(() {
      isLoading = true;
      isLoadingMore = false;
      showSearchBar = true;
      errorText = null;
      loadMoreError = null;
      gifs = [];
      hasMore = true;
    });

    try {
      final result = await api.loadGifs(requestQuery, 0);
      if (!mounted || requestQuery != query) return;
      setState(() {
        gifs = result;
        hasMore = result.length == pageSize;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestQuery != query) return;
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;

    final requestQuery = query;
    setState(() {
      isLoadingMore = true;
      loadMoreError = null;
    });

    try {
      final result = await api.loadGifs(requestQuery, gifs.length);
      if (!mounted || requestQuery != query) return;
      setState(() {
        gifs.addAll(result);
        hasMore = result.length == pageSize;
        isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || requestQuery != query) return;
      setState(() {
        loadMoreError = e.toString();
        isLoadingMore = false;
      });
    }
  }

  void onScroll() {
    final position = scrollController.position;

    bool shouldShow = showSearchBar;
    if (position.pixels <= 0) {
      shouldShow = true;
    } else if (position.userScrollDirection == ScrollDirection.reverse) {
      shouldShow = false;
    } else if (position.userScrollDirection == ScrollDirection.forward) {
      shouldShow = true;
    }
    if (shouldShow != showSearchBar) {
      setState(() {
        showSearchBar = shouldShow;
      });
    }

    if (position.pixels >= position.maxScrollExtent - 300 &&
        loadMoreError == null) {
      loadMore();
    }
  }

  void openDetail(Gif gif) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailScreen(gif: gif)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            buildBody(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: buildFloatingSearchBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFloatingSearchBar() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: showSearchBar ? Offset.zero : const Offset(0, -1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: showSearchBar ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SearchBar(
            controller: searchController,
            hintText: 'Search gifs...',
            leading: const Icon(Icons.search),
            onChanged: onSearchChanged,
            trailing: [
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text(errorText!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: loadFirstPage,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (gifs.isEmpty) {
      return const Center(child: Text('Nothing found'));
    }

    final width = MediaQuery.of(context).size.width;
    final columns = (width / 180).floor().clamp(2, 8);

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(8, 72, 8, 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount:
          gifs.length + ((isLoadingMore || loadMoreError != null) ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == gifs.length) {
          return buildBottomCell();
        }
        return buildGifCell(gifs[index]);
      },
    );
  }

  Widget buildGifCell(Gif gif) {
    return GestureDetector(
      onTap: () => openDetail(gif),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          gif.previewUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stack) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image)),
            );
          },
        ),
      ),
    );
  }

  Widget buildBottomCell() {
    if (loadMoreError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loadMoreError!, textAlign: TextAlign.center),
            TextButton(onPressed: loadMore, child: const Text('Retry')),
          ],
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
