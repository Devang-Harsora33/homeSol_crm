class AppAsset {
  final String name;
  final String assetName;
  final String assetCategory;
  final String assetFile;
  final String fullUrl;

  AppAsset({
    required this.name,
    required this.assetName,
    required this.assetCategory,
    required this.assetFile,
    required this.fullUrl,
  });

  factory AppAsset.fromJson(Map<String, dynamic> json) {
    return AppAsset(
      name: json['name'] ?? '',
      assetName: json['asset_name'] ?? '',
      assetCategory: json['asset_category'] ?? '',
      assetFile: json['asset_file'] ?? '',
      fullUrl: json['full_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'asset_name': assetName,
      'asset_category': assetCategory,
      'asset_file': assetFile,
      'full_url': fullUrl,
    };
  }
}
