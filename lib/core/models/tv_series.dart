import '../config/app_config.dart';
import 'watch_provider.dart';

class TvSeasonSummary {
  final int id;
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String? posterPath;
  final String? airDate;

  const TvSeasonSummary({
    required this.id,
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    this.posterPath,
    this.airDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'season_number': seasonNumber,
        'name': name,
        'episode_count': episodeCount,
        'poster_path': posterPath,
        'air_date': airDate,
      };

  factory TvSeasonSummary.fromJson(Map<String, dynamic> json) => TvSeasonSummary(
        id: json['id'] ?? 0,
        seasonNumber: json['season_number'] ?? json['seasonNumber'] ?? 1,
        name: json['name'] ?? 'Stagione ${json['season_number'] ?? 1}',
        episodeCount: json['episode_count'] ?? json['episodeCount'] ?? 0,
        posterPath: json['poster_path'] ?? json['posterPath'],
        airDate: json['air_date'] ?? json['airDate'],
      );
}

class TvEpisode {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? stillPath;
  final String? airDate;
  final int? runtime;
  final double voteAverage;

  const TvEpisode({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.airDate,
    this.runtime,
    this.voteAverage = 0.0,
  });

  String? get stillUrl =>
      stillPath != null ? '${AppConfig.tmdbImageBaseUrl}/w500$stillPath' : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'episode_number': episodeNumber,
        'season_number': seasonNumber,
        'name': name,
        'overview': overview,
        'still_path': stillPath,
        'air_date': airDate,
        'runtime': runtime,
        'vote_average': voteAverage,
      };

  factory TvEpisode.fromJson(Map<String, dynamic> json) => TvEpisode(
        id: json['id'] ?? 0,
        episodeNumber: json['episode_number'] ?? json['episodeNumber'] ?? 1,
        seasonNumber: json['season_number'] ?? json['seasonNumber'] ?? 1,
        name: json['name'] ?? 'Episodio ${json['episode_number'] ?? 1}',
        overview: json['overview'],
        stillPath: json['still_path'] ?? json['stillPath'],
        airDate: json['air_date'] ?? json['airDate'],
        runtime: json['runtime'],
        voteAverage: (json['vote_average'] ?? json['voteAverage'] ?? 0.0).toDouble(),
      );
}

class TvSeries {
  final int id;
  final String name;
  final String? originalName;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? firstAirDate;
  final int numberOfSeasons;
  final int numberOfEpisodes;
  final int currentSeason;
  final int currentEpisode;
  final String? currentEpisodeTitle;
  final Set<String> watchedEpisodeKeys;
  final String status; // 'queued', 'completed', 'dropped'
  final List<WatchProvider> providers;
  final List<TvSeasonSummary> seasons;
  final DateTime addedAt;
  final DateTime? lastWatchedAt;

  const TvSeries({
    required this.id,
    required this.name,
    this.originalName,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0.0,
    this.firstAirDate,
    this.numberOfSeasons = 1,
    this.numberOfEpisodes = 1,
    this.currentSeason = 1,
    this.currentEpisode = 1,
    this.currentEpisodeTitle,
    this.watchedEpisodeKeys = const {},
    this.status = 'queued',
    this.providers = const [],
    this.seasons = const [],
    required this.addedAt,
    this.lastWatchedAt,
  });

  String? get posterUrl =>
      posterPath != null ? '${AppConfig.tmdbImageBaseUrl}/w500$posterPath' : null;

  String? get backdropUrl =>
      backdropPath != null ? '${AppConfig.tmdbImageBaseUrl}/w1280$backdropPath' : null;

  String get year {
    if (firstAirDate != null && firstAirDate!.length >= 4) {
      return firstAirDate!.substring(0, 4);
    }
    return '';
  }

  int get totalWatchedEpisodes => watchedEpisodeKeys.length;

  int get remainingEpisodes {
    final rem = numberOfEpisodes - totalWatchedEpisodes;
    return rem < 0 ? 0 : rem;
  }

  double get progress {
    if (numberOfEpisodes <= 0) return 0.0;
    return (totalWatchedEpisodes / numberOfEpisodes).clamp(0.0, 1.0);
  }

  bool isEpisodeWatched(int season, int episode) {
    return watchedEpisodeKeys.contains('s${season}e$episode');
  }

  String get currentEpisodeDisplay {
    final prefix = 'S${currentSeason}E$currentEpisode';
    if (currentEpisodeTitle != null && currentEpisodeTitle!.isNotEmpty) {
      return '$prefix $currentEpisodeTitle';
    }
    return prefix;
  }

  TvSeries copyWith({
    int? id,
    String? name,
    String? originalName,
    String? overview,
    String? posterPath,
    String? backdropPath,
    double? voteAverage,
    String? firstAirDate,
    int? numberOfSeasons,
    int? numberOfEpisodes,
    int? currentSeason,
    int? currentEpisode,
    String? currentEpisodeTitle,
    Set<String>? watchedEpisodeKeys,
    String? status,
    List<WatchProvider>? providers,
    List<TvSeasonSummary>? seasons,
    DateTime? addedAt,
    DateTime? lastWatchedAt,
  }) {
    return TvSeries(
      id: id ?? this.id,
      name: name ?? this.name,
      originalName: originalName ?? this.originalName,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      voteAverage: voteAverage ?? this.voteAverage,
      firstAirDate: firstAirDate ?? this.firstAirDate,
      numberOfSeasons: numberOfSeasons ?? this.numberOfSeasons,
      numberOfEpisodes: numberOfEpisodes ?? this.numberOfEpisodes,
      currentSeason: currentSeason ?? this.currentSeason,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      currentEpisodeTitle: currentEpisodeTitle ?? this.currentEpisodeTitle,
      watchedEpisodeKeys: watchedEpisodeKeys ?? this.watchedEpisodeKeys,
      status: status ?? this.status,
      providers: providers ?? this.providers,
      seasons: seasons ?? this.seasons,
      addedAt: addedAt ?? this.addedAt,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'original_name': originalName,
        'overview': overview,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'vote_average': voteAverage,
        'first_air_date': firstAirDate,
        'number_of_seasons': numberOfSeasons,
        'number_of_episodes': numberOfEpisodes,
        'current_season': currentSeason,
        'current_episode': currentEpisode,
        'current_episode_title': currentEpisodeTitle,
        'watched_episode_keys': watchedEpisodeKeys.toList(),
        'status': status,
        'providers': providers.map((p) => p.toJson()).toList(),
        'seasons': seasons.map((s) => s.toJson()).toList(),
        'added_at': addedAt.toIso8601String(),
        'last_watched_at': lastWatchedAt?.toIso8601String(),
      };

  factory TvSeries.fromJson(Map<String, dynamic> json) {
    final watchedKeysRaw = json['watched_episode_keys'] ?? json['watchedEpisodeKeys'];
    final Set<String> keys = {};
    if (watchedKeysRaw is List) {
      for (final k in watchedKeysRaw) {
        keys.add(k.toString());
      }
    }

    final providersRaw = json['providers'];
    final List<WatchProvider> provList = [];
    if (providersRaw is List) {
      for (final p in providersRaw) {
        if (p is Map<String, dynamic>) {
          provList.add(WatchProvider.fromJson(p));
        }
      }
    }

    final seasonsRaw = json['seasons'];
    final List<TvSeasonSummary> seasonList = [];
    if (seasonsRaw is List) {
      for (final s in seasonsRaw) {
        if (s is Map<String, dynamic>) {
          seasonList.add(TvSeasonSummary.fromJson(s));
        }
      }
    }

    return TvSeries(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      originalName: json['original_name'] ?? json['originalName'],
      overview: json['overview'],
      posterPath: json['poster_path'] ?? json['posterPath'],
      backdropPath: json['backdrop_path'] ?? json['backdropPath'],
      voteAverage: (json['vote_average'] ?? json['voteAverage'] ?? 0.0).toDouble(),
      firstAirDate: json['first_air_date'] ?? json['firstAirDate'],
      numberOfSeasons: json['number_of_seasons'] ?? json['numberOfSeasons'] ?? 1,
      numberOfEpisodes: json['number_of_episodes'] ?? json['numberOfEpisodes'] ?? 1,
      currentSeason: json['current_season'] ?? json['currentSeason'] ?? 1,
      currentEpisode: json['current_episode'] ?? json['currentEpisode'] ?? 1,
      currentEpisodeTitle: json['current_episode_title'] ?? json['currentEpisodeTitle'],
      watchedEpisodeKeys: keys,
      status: json['status'] ?? 'queued',
      providers: provList,
      seasons: seasonList,
      addedAt: json['added_at'] != null
          ? DateTime.tryParse(json['added_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastWatchedAt: json['last_watched_at'] != null
          ? DateTime.tryParse(json['last_watched_at'].toString())
          : null,
    );
  }
}
