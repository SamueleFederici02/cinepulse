class LetterboxdMovie {
  final String slug;
  final String title;
  final int? year;
  final double? rating; // 0.5 to 5.0 (0.0 se non votato)
  final bool isLiked;
  final bool isInWatchlist;
  final DateTime? watchedDate;
  final String? reviewSnippet;
  final String? posterUrl;

  const LetterboxdMovie({
    required this.slug,
    required this.title,
    this.year,
    this.rating,
    this.isLiked = false,
    this.isInWatchlist = false,
    this.watchedDate,
    this.reviewSnippet,
    this.posterUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'title': title,
      'year': year,
      'rating': rating,
      'isLiked': isLiked,
      'isInWatchlist': isInWatchlist,
      'watchedDate': watchedDate?.toIso8601String(),
      'reviewSnippet': reviewSnippet,
      'posterUrl': posterUrl,
    };
  }

  factory LetterboxdMovie.fromJson(Map<String, dynamic> json) {
    return LetterboxdMovie(
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      year: json['year'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      isLiked: json['isLiked'] ?? false,
      isInWatchlist: json['isInWatchlist'] ?? false,
      watchedDate: json['watchedDate'] != null
          ? DateTime.tryParse(json['watchedDate'])
          : null,
      reviewSnippet: json['reviewSnippet'],
      posterUrl: json['posterUrl'],
    );
  }
}
