import 'watch_provider.dart';

class CastMember {
  final int id;
  final String name;
  final String? character;
  final String? profilePath;

  const CastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
  });

  String get profileUrl => profilePath != null
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=185';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'character': character,
    'profilePath': profilePath,
  };

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    character: json['character']?.toString(),
    profilePath: json['profile_path'] ?? json['profilePath'],
  );
}

class TmdbMovie {
  final int id;
  final String title;
  final String? originalTitle;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final int voteCount;
  final List<int> genreIds;
  final List<String> genres;
  final int? runtimeMinutes;
  final int? directorId;
  final String? director;
  final String? directorProfilePath;
  final List<String> cast;
  final List<CastMember> castMembers;
  final String? trailerKey;
  final Map<String, List<WatchProvider>> watchProviders; // 'IT' -> list of providers
  final double matchScore; // 0.0 to 100.0
  final List<String> matchReasons;
  final bool isInUserWatchlist;

  // Rating aggregati Rotten Tomatoes, Letterboxd, IMDb
  final String? rottenTomatoesScore; // es. "94%"
  final String? letterboxdScore;      // es. "4.3"
  final String? imdbScore;            // es. "8.6"
  final String? metacriticScore;      // es. "82%"

  const TmdbMovie({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    this.genreIds = const [],
    this.genres = const [],
    this.runtimeMinutes,
    this.directorId,
    this.director,
    this.directorProfilePath,
    this.cast = const [],
    this.castMembers = const [],
    this.trailerKey,
    this.watchProviders = const {},
    this.matchScore = 0.0,
    this.matchReasons = const [],
    this.isInUserWatchlist = false,
    this.rottenTomatoesScore,
    this.letterboxdScore,
    this.imdbScore,
    this.metacriticScore,
  });

  String? get directorProfileUrl => directorProfilePath != null
      ? 'https://image.tmdb.org/t/p/w185$directorProfilePath'
      : null;

  String get posterUrl => posterPath != null
      ? 'https://image.tmdb.org/t/p/w780$posterPath'
      : 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=780';

  String get backdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : posterUrl;

  String get releaseYear {
    if (releaseDate == null || releaseDate!.isEmpty) return '';
    return releaseDate!.split('-').first;
  }

  String get year => releaseYear;

  String get formattedRuntime {
    if (runtimeMinutes == null || runtimeMinutes == 0) return '';
    final hours = runtimeMinutes! ~/ 60;
    final mins = runtimeMinutes! % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  List<WatchProvider> providersForCountry(String countryCode) {
    return watchProviders[countryCode.toUpperCase()] ?? [];
  }

  List<WatchProvider> flatrateProviders(String countryCode) {
    return providersForCountry(countryCode)
        .where((p) => p.type == 'flatrate')
        .toList();
  }

  List<WatchProvider> rentProviders(String countryCode) {
    return providersForCountry(countryCode)
        .where((p) => p.type == 'rent')
        .toList();
  }

  List<WatchProvider> buyProviders(String countryCode) {
    return providersForCountry(countryCode)
        .where((p) => p.type == 'buy')
        .toList();
  }

  List<WatchProvider> freeProviders(String countryCode) {
    return providersForCountry(countryCode)
        .where((p) => p.type == 'free')
        .toList();
  }

  TmdbMovie copyWith({
    int? id,
    String? title,
    String? originalTitle,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    double? voteAverage,
    int? voteCount,
    List<int>? genreIds,
    List<String>? genres,
    int? runtimeMinutes,
    int? directorId,
    String? director,
    String? directorProfilePath,
    List<String>? cast,
    List<CastMember>? castMembers,
    String? trailerKey,
    Map<String, List<WatchProvider>>? watchProviders,
    double? matchScore,
    List<String>? matchReasons,
    bool? isInUserWatchlist,
    String? rottenTomatoesScore,
    String? letterboxdScore,
    String? imdbScore,
    String? metacriticScore,
  }) {
    return TmdbMovie(
      id: id ?? this.id,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      voteAverage: voteAverage ?? this.voteAverage,
      voteCount: voteCount ?? this.voteCount,
      genreIds: genreIds ?? this.genreIds,
      genres: genres ?? this.genres,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      directorId: directorId ?? this.directorId,
      director: director ?? this.director,
      directorProfilePath: directorProfilePath ?? this.directorProfilePath,
      cast: cast ?? this.cast,
      castMembers: castMembers ?? this.castMembers,
      trailerKey: trailerKey ?? this.trailerKey,
      watchProviders: watchProviders ?? this.watchProviders,
      matchScore: matchScore ?? this.matchScore,
      matchReasons: matchReasons ?? this.matchReasons,
      isInUserWatchlist: isInUserWatchlist ?? this.isInUserWatchlist,
      rottenTomatoesScore: rottenTomatoesScore ?? this.rottenTomatoesScore,
      letterboxdScore: letterboxdScore ?? this.letterboxdScore,
      imdbScore: imdbScore ?? this.imdbScore,
      metacriticScore: metacriticScore ?? this.metacriticScore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'release_date': releaseDate,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'genre_ids': genreIds,
      'genres': genres,
      'runtime': runtimeMinutes,
      'directorId': directorId,
      'director': director,
      'directorProfilePath': directorProfilePath,
      'cast': cast,
      'castMembers': castMembers.map((c) => c.toJson()).toList(),
      'trailerKey': trailerKey,
      'watchProviders': watchProviders.map(
        (k, v) => MapEntry(k, v.map((p) => p.toJson()).toList()),
      ),
      'matchScore': matchScore,
      'matchReasons': matchReasons,
      'isInUserWatchlist': isInUserWatchlist,
      'rottenTomatoesScore': rottenTomatoesScore,
      'letterboxdScore': letterboxdScore,
      'imdbScore': imdbScore,
      'metacriticScore': metacriticScore,
    };
  }

  factory TmdbMovie.fromJson(Map<String, dynamic> json) {
    List<int> gIds = [];
    if (json['genre_ids'] != null) {
      gIds = (json['genre_ids'] as List).map((e) => (e as num).toInt()).toList();
    } else if (json['genres'] != null && json['genres'] is List && (json['genres'] as List).isNotEmpty && json['genres'][0] is Map) {
      gIds = (json['genres'] as List)
          .map((e) => (e['id'] as num).toInt())
          .toList();
    }

    List<String> gNames = [];
    if (json['genres'] != null && json['genres'] is List) {
      for (final g in json['genres'] as List) {
        if (g is String) {
          gNames.add(g);
        } else if (g is Map && g['name'] != null) {
          gNames.add(g['name'].toString());
        }
      }
    }

    Map<String, List<WatchProvider>>? providers;
    if (json['watchProviders'] != null && json['watchProviders'] is Map) {
      providers = {};
      (json['watchProviders'] as Map).forEach((k, v) {
        if (v is List) {
          providers![k.toString()] = v
              .map((item) => WatchProvider.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      });
    }

    List<CastMember> members = [];
    if (json['castMembers'] != null && json['castMembers'] is List) {
      members = (json['castMembers'] as List)
          .map((c) => CastMember.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return TmdbMovie(
      id: (json['id'] as num).toInt(),
      title: json['title'] ?? json['name'] ?? '',
      originalTitle: json['original_title'],
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: json['release_date'] ?? json['first_air_date'],
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      genreIds: gIds,
      genres: gNames,
      runtimeMinutes: (json['runtime'] as num?)?.toInt(),
      directorId: (json['directorId'] as num?)?.toInt(),
      director: json['director']?.toString(),
      directorProfilePath: json['directorProfilePath']?.toString(),
      cast: json['cast'] != null ? List<String>.from(json['cast'] as List) : const [],
      castMembers: members,
      trailerKey: json['trailerKey']?.toString(),
      watchProviders: providers ?? const {},
      matchScore: (json['matchScore'] as num?)?.toDouble() ?? 0.0,
      matchReasons: json['matchReasons'] != null ? List<String>.from(json['matchReasons'] as List) : const [],
      isInUserWatchlist: (json['isInUserWatchlist'] as bool?) ?? false,
      rottenTomatoesScore: json['rottenTomatoesScore']?.toString(),
      letterboxdScore: json['letterboxdScore']?.toString(),
      imdbScore: json['imdbScore']?.toString(),
      metacriticScore: json['metacriticScore']?.toString(),
    );
  }
}
