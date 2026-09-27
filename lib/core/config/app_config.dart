class AppConfig {
  static const String appName = 'CinePulse';

  // Chiave TMDb pre-configurata integrata
  static const String tmdbApiKey = '2dca580c2a14b55200e784d157207b4d';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p';

  // OMDb API Key pubblica per Rotten Tomatoes e IMDb ratings
  static const String omdbApiKey = 'trilogy';

  // Tutte le nazioni supportate da TMDb / JustWatch per lo streaming
  static const Map<String, String> supportedCountries = {
    'IT': 'Italia 🇮🇹',
    'US': 'Stati Uniti 🇺🇸',
    'GB': 'Regno Unito 🇬🇧',
    'FR': 'Francia 🇫🇷',
    'DE': 'Germania 🇩🇪',
    'ES': 'Spagna 🇪🇸',
    'CA': 'Canada 🇨🇦',
    'AU': 'Australia 🇦🇺',
    'JP': 'Giappone 🇯🇵',
    'BR': 'Brasile 🇧🇷',
    'MX': 'Messico 🇲🇽',
    'NL': 'Paesi Bassi 🇳🇱',
    'CH': 'Svizzera 🇨🇭',
    'AT': 'Austria 🇦🇹',
    'BE': 'Belgio 🇧🇪',
    'PT': 'Portogallo 🇵🇹',
    'SE': 'Svezia 🇸🇪',
    'NO': 'Norvegia 🇳🇴',
    'DK': 'Danimarca 🇩🇰',
    'FI': 'Finlandia 🇫🇮',
    'PL': 'Polonia 🇵🇱',
    'IE': 'Irlanda 🇮🇪',
    'AR': 'Argentina 🇦🇷',
    'KR': 'Corea del Sud 🇰🇷',
    'IN': 'India 🇮🇳',
    'NZ': 'Nuova Zelanda 🇳🇿',
    'CL': 'Cile 🇨🇱',
    'CO': 'Colombia 🇨🇴',
    'GR': 'Grecia 🇬🇷',
    'TR': 'Turchia 🇹🇷',
    'CZ': 'Rep. Ceca 🇨🇿',
    'HU': 'Ungheria 🇭🇺',
    'RO': 'Romania 🇷🇴',
    'ZA': 'Sudafrica 🇿🇦',
  };

  /// Lista delle piattaforme di streaming con loghi ufficiali, ordinata alfabeticamente
  static List<Map<String, String>> getKnownProvidersForCountry(String countryCode) {
    return [
      {'name': 'Amazon Prime Video', 'logo': 'https://image.tmdb.org/t/p/w92/gMZdpavHmxFNnLpMHwVxfqeux2g.png'},
      {'name': 'Apple TV+', 'logo': 'https://image.tmdb.org/t/p/w92/9icYBfYFcwgCbky5VdGUIKJ4C5i.png'},
      {'name': 'Chili', 'logo': 'https://image.tmdb.org/t/p/w92/jFpmTkn5mt5z8H4dmOQvMbmkpHa.png'},
      {'name': 'Crunchyroll', 'logo': 'https://image.tmdb.org/t/p/w92/fz6U4o7u7bYj9e3Fk7M6iWcM6jM.png'},
      {'name': 'Discovery+', 'logo': 'https://image.tmdb.org/t/p/w92/gkTqX0VpG4w9X8N9WJ1Z1q3Y2eD.png'},
      {'name': 'Disney Plus', 'logo': 'https://image.tmdb.org/t/p/w92/5eZ872CghnHFLB1j8grszbrx0dx.png'},
      {'name': 'Google Play Film', 'logo': 'https://image.tmdb.org/t/p/w92/aZRENwYILujqs0RVOZutTh0BVGV.png'},
      {'name': 'HBO Max', 'logo': 'https://image.tmdb.org/t/p/w92/aS2zvJWn97WiQ71W08YENIm7Ce.png'},
      {'name': 'Infinity+', 'logo': 'https://image.tmdb.org/t/p/w92/rj7ggYclu9eHRM5sNHAWVuzegU8.png'},
      {'name': 'Mediaset Infinity', 'logo': 'https://image.tmdb.org/t/p/w92/sisoTNsbDwCtSEBl6thqfJYK17x.png'},
      {'name': 'MUBI', 'logo': 'https://image.tmdb.org/t/p/w92/k7iSlvgWzZuO4zU5PcBjhABMuia.png'},
      {'name': 'Netflix', 'logo': 'https://image.tmdb.org/t/p/w92/rK1KljqmbvO9HQa1PBFLILWah72.png'},
      {'name': 'NOW', 'logo': 'https://image.tmdb.org/t/p/w92/oFAnvlaEW2KT6J7XM0DXjlWqKu9.png'},
      {'name': 'Paramount Plus', 'logo': 'https://image.tmdb.org/t/p/w92/pkx3klJlwW5JdtaulvDx6hDNtch.png'},
      {'name': 'Pluto TV', 'logo': 'https://image.tmdb.org/t/p/w92/b8S2c9j9n0p2h4hJ7R6iX2yM1q3.png'},
      {'name': 'RaiPlay', 'logo': 'https://image.tmdb.org/t/p/w92/zW9XFk3aMvj0yQ9nK5R7pW2xX1y.png'},
      {'name': 'Rakuten TV', 'logo': 'https://image.tmdb.org/t/p/w92/872dfVu1biZISJ8rO143CZZutPR.png'},
      {'name': 'Sky Go', 'logo': 'https://image.tmdb.org/t/p/w92/1Yvl9eP3pmktqChitnFhHJHcBtX.png'},
      {'name': 'TIMVISION', 'logo': 'https://image.tmdb.org/t/p/w92/iGb7XGcCiCZyBgBqIdSEBiOxNc4.png'},
      {'name': 'YouTube', 'logo': 'https://image.tmdb.org/t/p/w92/1n8XjXf3V4N4Fm3Z3xR1c8v3W.png'},
    ];
  }

  // Mappa ID Genere TMDb -> Nome in Italiano
  static const Map<int, String> genreMap = {
    28: 'Azione',
    12: 'Avventura',
    16: 'Animazione',
    35: 'Commedia',
    80: 'Crime',
    99: 'Documentario',
    18: 'Drammatico',
    10751: 'Famiglia',
    14: 'Fantasy',
    36: 'Storia',
    27: 'Horror',
    10402: 'Musica',
    9648: 'Mistero',
    10749: 'Romance',
    878: 'Fantascienza',
    10770: 'Film TV',
    53: 'Thriller',
    10752: 'Guerra',
    37: 'Western',
  };

  static int? getGenreIdByName(String name) {
    final lower = name.toLowerCase().trim();
    for (final entry in genreMap.entries) {
      if (entry.value.toLowerCase() == lower) {
        return entry.key;
      }
    }
    final englishMap = {
      'action': 28,
      'adventure': 12,
      'animation': 16,
      'comedy': 35,
      'crime': 80,
      'documentary': 99,
      'drama': 18,
      'family': 10751,
      'fantasy': 14,
      'history': 36,
      'horror': 27,
      'music': 10402,
      'mystery': 9648,
      'romance': 10749,
      'science fiction': 878,
      'sci-fi': 878,
      'thriller': 53,
      'war': 10752,
      'western': 37,
    };
    return englishMap[lower];
  }
}
