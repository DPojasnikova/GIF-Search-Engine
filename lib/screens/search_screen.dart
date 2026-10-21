import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config.dart';
import '../gif_model.dart';
import '../giphy_api.dart';
import 'detail_screen.dart';

// Screen 1: search field and a grid of gifs
class SearchScreen extends StatefulWidget {
  // The api can be passed in from outside (tests use a fake one)
  final GiphyApi? api;

  const SearchScreen({super.key, this.api});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final GiphyApi api = widget.api ?? GiphyApi();
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  Timer? searchTimer; // timer for the delay before searching

  List<Gif> gifs = [];
  String query = ''; // current search query
  bool isLoading = false; // the first page is loading
  bool isLoadingMore = false; // the next page is loading
  bool hasMore = true; // are there more gifs on the server
  String? errorText; // error of the first load
  String? loadMoreError; // error of loading the next page
  bool showSearchBar = true; // the floating search field is visible

  @override
  void initState() {
    super.initState();
    scrollController.addListener(onScroll);
    loadFirstPage(); // show trending gifs right away
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // The user typed something: wait for a pause and only then search
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

  // Loads the first page again (new search or the "Retry" button)
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
      // While the request was running the user could type another text,
      // then this result is outdated and we ignore it
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

  // Loads the next page
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

  // Called on every scroll. Hides or shows the search field and
  // loads more gifs when the user is close to the bottom.
  void onScroll() {
    final position = scrollController.position;

    // Scrolling down hides the search field, scrolling up shows it.
    // At the very top it is always visible.
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
    // The grid fills the whole screen and the search field floats over it
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

  // The search field. It slides up and fades out when it is hidden.
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
    // 1. First load: a spinner in the center
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Error of the first load
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

    // 3. Nothing found
    if (gifs.isEmpty) {
      return const Center(child: Text('Nothing found'));
    }

    // 4. The grid. The number of columns depends on the screen width,
    // so in landscape mode there are more columns.
    final width = MediaQuery.of(context).size.width;
    final columns = (width / 180).floor().clamp(2, 8);

    return GridView.builder(
      controller: scrollController,
      // The top padding leaves room for the floating search field,
      // so it does not cover the first row
      padding: const EdgeInsets.fromLTRB(8, 72, 8, 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      // +1 is an extra cell at the bottom for a spinner or an error
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
          // While the image is loading, show a spinner
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          // If the image failed to load, show an error icon
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
