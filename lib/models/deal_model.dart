class DealModel {
  final int id;
  final String clientName;
  final String paymentMethod;
  final String status; // 'reservation', 'contracted', 'closed'
  final String stage; // 'won', 'lost', 'on_hold', 'in_progress', 'cancelled'
  final double value;
  final DateTime? reminderDate;
  final int? leadId;
  final int? client; // API client ID
  final int? company; // API company ID
  final int? employee; // API employee ID
  final int? startedBy; // user ID
  final int? closedBy; // user ID
  final String? startDate;
  final String? closedDate;
  final double? discountPercentage;
  final double? discountAmount;
  final double? salesCommissionPercentage;
  final double? salesCommissionAmount;
  final String? description;
  final dynamic unit; // For real estate - can be ID (number) or code (string) from API
  final dynamic project; // For real estate - can be ID (number) or name (string) from API
  final String? unitCode; // Read-only field from API serializer
  final String? projectName; // Read-only field from API serializer
  final String? createdAt;
  final String? updatedAt;

  // Configurable pipeline (read-only denormalized names come from the API).
  // All null for deals the API has not mapped onto a pipeline stage; screens
  // then fall back to the legacy [stage] enum.
  final int? pipeline;
  final String? pipelineName;
  final int? pipelineStage;
  final String? pipelineStageName;
  final String? pipelineStageColor; // '#RRGGBB'
  final String? stageType; // 'open' | 'won' | 'lost'
  final int? lostReason;
  final String? lostReasonName;
  final String? lostNote;

  DealModel({
    required this.id,
    required this.clientName,
    required this.paymentMethod,
    required this.status,
    required this.stage,
    required this.value,
    this.reminderDate,
    this.leadId,
    this.client,
    this.company,
    this.employee,
    this.startedBy,
    this.closedBy,
    this.startDate,
    this.closedDate,
    this.discountPercentage,
    this.discountAmount,
    this.salesCommissionPercentage,
    this.salesCommissionAmount,
    this.description,
    this.unit,
    this.project,
    this.unitCode,
    this.projectName,
    this.createdAt,
    this.updatedAt,
    this.pipeline,
    this.pipelineName,
    this.pipelineStage,
    this.pipelineStageName,
    this.pipelineStageColor,
    this.stageType,
    this.lostReason,
    this.lostReasonName,
    this.lostNote,
  });

  /// True when the deal sits in a configurable "lost" stage, or (legacy deals
  /// with no pipeline stage) has the legacy `lost` stage value.
  bool get isLost => stageType != null ? stageType == 'lost' : stage == 'lost';

  factory DealModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse doubles from various types
    double parseToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse nullable doubles
    double? parseToDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed;
      }
      return null;
    }

    // Handle clientName - API might return client_name, clientName, or client object
    String clientName = '';
    if (json['client_name'] != null) {
      clientName = json['client_name'] as String? ?? '';
    } else if (json['clientName'] != null) {
      clientName = json['clientName'] as String? ?? '';
    } else if (json['client'] != null) {
      if (json['client'] is Map) {
        clientName = (json['client'] as Map<String, dynamic>)['name'] as String? ?? '';
      } else if (json['client'] is String) {
        clientName = json['client'] as String;
      }
    }

    // Handle project - API might return project_name, project, or project object
    dynamic project;
    if (json['project_name'] != null) {
      project = json['project_name'] as String?;
    } else if (json['project'] != null) {
      project = json['project'];
    }

    // Handle unit - API might return unit_code, unit, or unit object
    dynamic unit;
    if (json['unit_code'] != null) {
      unit = json['unit_code'] as String?;
    } else if (json['unit'] != null) {
      unit = json['unit'];
    }

    return DealModel(
      id: json['id'] as int,
      clientName: clientName,
      paymentMethod: json['payment_method'] as String? ?? json['paymentMethod'] as String? ?? '',
      status: json['status'] as String? ?? '',
      stage: json['stage'] as String? ?? '',
      value: parseToDouble(json['value']),
      reminderDate: json['reminder_date'] != null
          ? DateTime.tryParse(json['reminder_date'] as String)
          : (json['reminderDate'] != null ? DateTime.tryParse(json['reminderDate'] as String) : null),
      leadId: json['lead_id'] as int? ?? json['leadId'] as int?,
      client: json['client'] is int ? json['client'] as int : null,
      company: json['company'] is int ? json['company'] as int : (json['company'] is Map ? (json['company'] as Map<String, dynamic>)['id'] as int? : null),
      employee: json['employee'] as int?,
      startedBy: json['started_by'] as int? ?? json['startedBy'] as int?,
      closedBy: json['closed_by'] as int? ?? json['closedBy'] as int?,
      startDate: json['start_date'] as String? ?? json['startDate'] as String?,
      closedDate: json['closed_date'] as String? ?? json['closedDate'] as String?,
      discountPercentage: parseToDoubleNullable(json['discount_percentage'] ?? json['discountPercentage']),
      discountAmount: parseToDoubleNullable(json['discount_amount'] ?? json['discountAmount']),
      salesCommissionPercentage: parseToDoubleNullable(json['sales_commission_percentage'] ?? json['salesCommissionPercentage']),
      salesCommissionAmount: parseToDoubleNullable(json['sales_commission_amount'] ?? json['salesCommissionAmount']),
      description: json['description'] as String?,
      unit: unit,
      project: project,
      unitCode: json['unit_code'] as String?,
      projectName: json['project_name'] as String?,
      createdAt: json['created_at'] as String? ?? json['createdAt'] as String?,
      updatedAt: json['updated_at'] as String? ?? json['updatedAt'] as String?,
      pipeline: json['pipeline'] as int?,
      pipelineName: json['pipeline_name'] as String?,
      pipelineStage: json['pipeline_stage'] as int?,
      pipelineStageName: json['pipeline_stage_name'] as String?,
      pipelineStageColor: json['pipeline_stage_color'] as String?,
      stageType: json['stage_type'] as String?,
      lostReason: json['lost_reason'] as int?,
      lostReasonName: json['lost_reason_name'] as String?,
      lostNote: json['lost_note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_name': clientName,
      'payment_method': paymentMethod,
      'status': status,
      'stage': stage,
      'value': value,
      'reminder_date': reminderDate?.toIso8601String(),
      'lead_id': leadId,
      'client': client,
      'company': company,
      'employee': employee,
      'started_by': startedBy,
      'closed_by': closedBy,
      'start_date': startDate,
      'closed_date': closedDate,
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
      'sales_commission_percentage': salesCommissionPercentage,
      'sales_commission_amount': salesCommissionAmount,
      'description': description,
      'unit': unit,
      'project': project,
      'unit_code': unitCode,
      'project_name': projectName,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'pipeline': pipeline,
      'pipeline_name': pipelineName,
      'pipeline_stage': pipelineStage,
      'pipeline_stage_name': pipelineStageName,
      'pipeline_stage_color': pipelineStageColor,
      'stage_type': stageType,
      'lost_reason': lostReason,
      'lost_reason_name': lostReasonName,
      'lost_note': lostNote,
    };
  }
}

