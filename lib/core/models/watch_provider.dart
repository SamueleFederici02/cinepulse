class WatchProvider {
  final int providerId;
  final String providerName;
  final String logoPath;
  final String type; // 'flatrate' (abbonamento), 'rent' (noleggio), 'buy' (acquisto), 'free'

  const WatchProvider({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
    required this.type,
  });

  String get fullLogoUrl => 'https://image.tmdb.org/t/p/w154$logoPath';
  String get logoUrl => fullLogoUrl;

  Map<String, dynamic> toJson() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'logoPath': logoPath,
      'type': type,
    };
  }

  factory WatchProvider.fromJson(Map<String, dynamic> json, {String type = 'flatrate'}) {
    return WatchProvider(
      providerId: json['provider_id'] ?? json['providerId'] ?? 0,
      providerName: json['provider_name'] ?? json['providerName'] ?? '',
      logoPath: json['logo_path'] ?? json['logoPath'] ?? '',
      type: json['type'] ?? type,
    );
  }
}
