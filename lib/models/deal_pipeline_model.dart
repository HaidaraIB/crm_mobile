import 'dart:ui' show Color;

/// Parses a `#RRGGBB` hex string from the API into an opaque [Color].
/// Returns null when the value is missing or malformed.
Color? dealColorFromHex(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.trim().replaceAll('#', '');
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// Mirrors `settings.DealStageType` on the API.
class DealStageType {
  static const open = 'open';
  static const won = 'won';
  static const lost = 'lost';
}

class DealStageModel {
  final int id;
  final int pipeline;
  final String name;
  final String color; // '#RRGGBB'
  final int order;
  final String stageType; // open | won | lost
  final int probability;
  final String? systemKey; // in_progress | on_hold | won | lost | cancelled
  final bool isActive;

  const DealStageModel({
    required this.id,
    required this.pipeline,
    required this.name,
    required this.color,
    required this.order,
    required this.stageType,
    required this.probability,
    this.systemKey,
    this.isActive = true,
  });

  bool get isLost => stageType == DealStageType.lost;
  bool get isWon => stageType == DealStageType.won;
  bool get isOpen => stageType == DealStageType.open;

  /// Legacy `Deal.stage` value the API still accepts alongside `pipeline_stage`.
  String get legacyStage {
    const legacyKeys = {'in_progress', 'on_hold', 'won', 'lost', 'cancelled'};
    final key = systemKey;
    if (key != null && legacyKeys.contains(key)) return key;
    if (isWon) return 'won';
    if (isLost) return 'lost';
    return 'in_progress';
  }

  factory DealStageModel.fromJson(Map<String, dynamic> json) {
    return DealStageModel(
      id: json['id'] as int,
      pipeline: json['pipeline'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#3B82F6',
      order: json['order'] as int? ?? 0,
      stageType: json['stage_type'] as String? ?? DealStageType.open,
      probability: (json['probability'] as num?)?.toInt() ?? 0,
      systemKey: json['system_key'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class DealPipelineModel {
  final int id;
  final String name;
  final int order;
  final bool isDefault;
  final bool isActive;
  final List<DealStageModel> stages;

  const DealPipelineModel({
    required this.id,
    required this.name,
    required this.order,
    required this.isDefault,
    required this.isActive,
    required this.stages,
  });

  /// Active stages in display order.
  List<DealStageModel> get activeStages {
    final list = stages.where((s) => s.isActive).toList();
    list.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
    return list;
  }

  /// Stage a brand-new deal should start in: the `in_progress` system stage,
  /// otherwise the first open stage, otherwise the first stage.
  DealStageModel? get initialStage {
    final active = activeStages;
    if (active.isEmpty) return null;
    for (final s in active) {
      if (s.systemKey == 'in_progress') return s;
    }
    for (final s in active) {
      if (s.isOpen) return s;
    }
    return active.first;
  }

  factory DealPipelineModel.fromJson(Map<String, dynamic> json) {
    final rawStages = json['stages'] as List<dynamic>? ?? const [];
    return DealPipelineModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      stages: rawStages
          .whereType<Map<String, dynamic>>()
          .map(DealStageModel.fromJson)
          .toList(),
    );
  }
}

class DealLostReasonModel {
  final int id;
  final String name;
  final int order;
  final bool isActive;

  const DealLostReasonModel({
    required this.id,
    required this.name,
    required this.order,
    this.isActive = true,
  });

  factory DealLostReasonModel.fromJson(Map<String, dynamic> json) {
    return DealLostReasonModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
