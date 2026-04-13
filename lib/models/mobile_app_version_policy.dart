/// Server policy from `GET /public/mobile-app-version/`.
class MobileAppVersionPolicy {
  const MobileAppVersionPolicy({
    required this.minimumVersionAndroid,
    required this.minimumVersionIos,
    this.minimumBuildAndroid,
    this.minimumBuildIos,
    required this.storeUrlAndroid,
    required this.storeUrlIos,
  });

  final String minimumVersionAndroid;
  final String minimumVersionIos;
  final int? minimumBuildAndroid;
  final int? minimumBuildIos;
  final String storeUrlAndroid;
  final String storeUrlIos;

  factory MobileAppVersionPolicy.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return MobileAppVersionPolicy(
      minimumVersionAndroid:
          json['minimum_version_android']?.toString().trim() ?? '',
      minimumVersionIos:
          json['minimum_version_ios']?.toString().trim() ?? '',
      minimumBuildAndroid: parseInt(json['minimum_build_android']),
      minimumBuildIos: parseInt(json['minimum_build_ios']),
      storeUrlAndroid: json['store_url_android']?.toString().trim() ?? '',
      storeUrlIos: json['store_url_ios']?.toString().trim() ?? '',
    );
  }
}
