class Gif {
  final String id;
  final String title;
  final String previewUrl;
  final String originalUrl;
  final String username;
  final String rating;
  final String pageUrl;

  Gif({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.originalUrl,
    required this.username,
    required this.rating,
    required this.pageUrl,
  });

  factory Gif.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>;
    final preview = images['fixed_width'] as Map<String, dynamic>;
    final original = images['original'] as Map<String, dynamic>;

    return Gif(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      previewUrl: preview['url'] as String,
      originalUrl: original['url'] as String,
      username: (json['username'] as String?) ?? '',
      rating: (json['rating'] as String?) ?? '',
      pageUrl: (json['url'] as String?) ?? '',
    );
  }
}
