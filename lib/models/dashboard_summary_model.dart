class DashboardLeadsOverview {
  final int total;
  final int fresh;
  final int cold;
  final int untouched;
  final int touched;
  final int following;

  const DashboardLeadsOverview({
    required this.total,
    required this.fresh,
    required this.cold,
    required this.untouched,
    required this.touched,
    required this.following,
  });

  factory DashboardLeadsOverview.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => (v as num?)?.toInt() ?? 0;
    return DashboardLeadsOverview(
      total: asInt(json['total']),
      fresh: asInt(json['fresh']),
      cold: asInt(json['cold']),
      untouched: asInt(json['untouched']),
      touched: asInt(json['touched']),
      following: asInt(json['following']),
    );
  }

  static const empty = DashboardLeadsOverview(
    total: 0,
    fresh: 0,
    cold: 0,
    untouched: 0,
    touched: 0,
    following: 0,
  );
}

/// Lite dashboard-summary payload used by the mobile home screen.
class DashboardSummaryLite {
  final DashboardLeadsOverview overview;
  final bool lite;

  const DashboardSummaryLite({
    required this.overview,
    this.lite = true,
  });

  factory DashboardSummaryLite.fromJson(Map<String, dynamic> json) {
    final overviewJson = json['overview'];
    return DashboardSummaryLite(
      overview: overviewJson is Map<String, dynamic>
          ? DashboardLeadsOverview.fromJson(overviewJson)
          : DashboardLeadsOverview.empty,
      lite: json['lite'] == true,
    );
  }
}
