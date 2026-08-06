class LeadModel {
  final int id;
  final String name;
  final String phone;
  final String? status;
  final String type; // 'fresh', 'hot', 'cold', etc.
  final int assignedTo;
  final double budget;
  /// Upper bound when budget is a range; null means single value ([budget] only).
  final double? budgetMax;
  final String? communicationWay;
  final String? priority; // 'High', 'Medium', 'Low'
  /// Prefer on-shift assignee when true (API: is_urgent).
  final bool isUrgent;
  final DateTime createdAt;
  final String? lastFeedback;
  final DateTime? lastFeedbackAt;
  final String? notes;
  final String? lastStage;
  final String? statusName;
  final List<PhoneNumber>? phoneNumbers;
  final String? leadCompanyName;
  final String? profession;
  final String? residence;
  /// Per-company clinic file number (API: patient_file_number), read-only.
  final int? patientFileNumber;
  /// CRM user id who created the lead (null for integrations / legacy).
  final int? createdBy;
  final String? createdByName;
  final double? locationLatitude;
  final double? locationLongitude;
  final int? interestedDeveloper;
  final int? interestedProject;
  final int? interestedUnit;
  final String? interestedDeveloperName;
  final String? interestedProjectName;
  final String? interestedUnitName;
  final String? interestedUnitCode;
  final String? source;
  final int? campaign;
  final String? campaignName;
  final String? metaLeadgenId;
  /// null | qualified | unqualified
  final String? metaQualificationStatus;
  final DateTime? metaQualificationSentAt;
  final MetaQualificationError? metaQualificationError;

  LeadModel({
    required this.id,
    required this.name,
    required this.phone,
    this.status,
    required this.type,
    required this.assignedTo,
    required this.budget,
    this.budgetMax,
    this.communicationWay,
    this.priority,
    this.isUrgent = false,
    required this.createdAt,
    this.lastFeedback,
    this.lastFeedbackAt,
    this.notes,
    this.lastStage,
    this.statusName,
    this.phoneNumbers,
    this.leadCompanyName,
    this.profession,
    this.residence,
    this.patientFileNumber,
    this.createdBy,
    this.createdByName,
    this.locationLatitude,
    this.locationLongitude,
    this.interestedDeveloper,
    this.interestedProject,
    this.interestedUnit,
    this.interestedDeveloperName,
    this.interestedProjectName,
    this.interestedUnitName,
    this.interestedUnitCode,
    this.source,
    this.campaign,
    this.campaignName,
    this.metaLeadgenId,
    this.metaQualificationStatus,
    this.metaQualificationSentAt,
    this.metaQualificationError,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    String? toStringOrNull(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    double? toDoubleOrNull(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    int? toIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    String? statusValue = toStringOrNull(json['status']);

    String? phoneValue =
        toStringOrNull(json['phone']) ?? toStringOrNull(json['phone_number']);

    String? communicationWayValue = json['communication_way_name'] as String?;
    communicationWayValue ??=
        toStringOrNull(json['communication_way']) ??
        toStringOrNull(json['communicationWay']);

    int? createdById;
    final rawCreatedBy = json['created_by'] ?? json['createdBy'];
    if (rawCreatedBy != null) {
      createdById = toIntOrNull(rawCreatedBy);
      if (createdById != null && createdById <= 0) createdById = null;
    }
    final createdByNameValue =
        json['created_by_name'] as String? ?? json['createdByName'] as String?;

    DateTime? parseDt(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return LeadModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: phoneValue ?? '',
      status: statusValue,
      type: toStringOrNull(json['type']) ?? 'All',
      assignedTo: toInt(json['assigned_to'] ?? json['assignedTo'], 0),
      budget: toDouble(json['budget']),
      budgetMax: toDoubleOrNull(json['budget_max'] ?? json['budgetMax']),
      communicationWay: communicationWayValue,
      priority: toStringOrNull(json['priority']),
      isUrgent: json['is_urgent'] == true || json['isUrgent'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now()),
      lastFeedback:
          json['last_feedback'] as String? ?? json['lastFeedback'] as String?,
      lastFeedbackAt: parseDt(json['last_feedback_at']) ??
          parseDt(json['lastFeedbackAt']),
      notes: json['notes'] as String?,
      lastStage: json['last_stage'] as String? ?? json['lastStage'] as String?,
      statusName: json['status_name'] as String?,
      phoneNumbers: json['phone_numbers'] != null
          ? (json['phone_numbers'] as List)
              .map((e) => PhoneNumber.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      leadCompanyName: json['lead_company_name'] as String?,
      profession: json['profession'] as String?,
      residence: json['residence'] as String?,
      patientFileNumber: toIntOrNull(
        json['patient_file_number'] ?? json['patientFileNumber'],
      ),
      createdBy: createdById,
      createdByName: createdByNameValue,
      locationLatitude: toDoubleOrNull(json['location_latitude']),
      locationLongitude: toDoubleOrNull(json['location_longitude']),
      interestedDeveloper: toIntOrNull(
        json['interested_developer'] ?? json['interestedDeveloper'],
      ),
      interestedProject: toIntOrNull(
        json['interested_project'] ?? json['interestedProject'],
      ),
      interestedUnit: toIntOrNull(
        json['interested_unit'] ?? json['interestedUnit'],
      ),
      interestedDeveloperName:
          json['interested_developer_name'] as String? ??
          json['interestedDeveloperName'] as String?,
      interestedProjectName:
          json['interested_project_name'] as String? ??
          json['interestedProjectName'] as String?,
      interestedUnitName:
          json['interested_unit_name'] as String? ??
          json['interestedUnitName'] as String?,
      interestedUnitCode:
          json['interested_unit_code'] as String? ??
          json['interestedUnitCode'] as String?,
      source: toStringOrNull(json['source']),
      campaign: toIntOrNull(json['campaign']),
      campaignName:
          json['campaign_name'] as String? ?? json['campaignName'] as String?,
      metaLeadgenId:
          toStringOrNull(json['meta_leadgen_id'] ?? json['metaLeadgenId']),
      metaQualificationStatus: toStringOrNull(
        json['meta_qualification_status'] ?? json['metaQualificationStatus'],
      ),
      metaQualificationSentAt: parseDt(
            json['meta_qualification_sent_at'],
          ) ??
          parseDt(json['metaQualificationSentAt']),
      metaQualificationError: MetaQualificationError.fromJson(
        json['meta_qualification_error'] ?? json['metaQualificationError'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'status': status,
      'type': type,
      'assigned_to': assignedTo,
      'budget': budget,
      if (budgetMax != null) 'budget_max': budgetMax,
      'communication_way': communicationWay,
      'priority': priority,
      'is_urgent': isUrgent,
      'created_at': createdAt.toIso8601String(),
      'last_feedback': lastFeedback,
      'last_feedback_at': lastFeedbackAt?.toIso8601String(),
      'notes': notes,
      'last_stage': lastStage,
      'status_name': statusName,
      'phone_numbers': phoneNumbers?.map((e) => e.toJson()).toList(),
      'lead_company_name': leadCompanyName,
      'profession': profession,
      if (residence != null) 'residence': residence,
      if (patientFileNumber != null) 'patient_file_number': patientFileNumber,
      if (createdBy != null) 'created_by': createdBy,
      if (createdByName != null) 'created_by_name': createdByName,
      if (locationLatitude != null) 'location_latitude': locationLatitude,
      if (locationLongitude != null) 'location_longitude': locationLongitude,
      if (interestedDeveloper != null)
        'interested_developer': interestedDeveloper,
      if (interestedProject != null) 'interested_project': interestedProject,
      if (interestedUnit != null) 'interested_unit': interestedUnit,
      if (interestedDeveloperName != null)
        'interested_developer_name': interestedDeveloperName,
      if (interestedProjectName != null)
        'interested_project_name': interestedProjectName,
      if (interestedUnitName != null)
        'interested_unit_name': interestedUnitName,
      if (interestedUnitCode != null)
        'interested_unit_code': interestedUnitCode,
      if (source != null) 'source': source,
      if (campaign != null) 'campaign': campaign,
      if (campaignName != null) 'campaign_name': campaignName,
      if (metaLeadgenId != null) 'meta_leadgen_id': metaLeadgenId,
      if (metaQualificationStatus != null)
        'meta_qualification_status': metaQualificationStatus,
      if (metaQualificationSentAt != null)
        'meta_qualification_sent_at':
            metaQualificationSentAt!.toIso8601String(),
      if (metaQualificationError != null)
        'meta_qualification_error': metaQualificationError!.toJson(),
    };
  }
}

class MetaQualificationError {
  final String key;
  final String message;

  const MetaQualificationError({required this.key, this.message = ''});

  static MetaQualificationError? fromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      if (raw.isEmpty) return null;
      return MetaQualificationError(key: raw);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final key = (map['key'] ?? map['error_key'] ?? '').toString();
      if (key.isEmpty) return null;
      return MetaQualificationError(
        key: key,
        message: (map['message'] ?? '').toString(),
      );
    }
    return null;
  }

  Map<String, dynamic> toJson() => {'key': key, 'message': message};
}

class PhoneNumber {
  final int id;
  final String phoneNumber;
  final String phoneType; // 'mobile', 'home', 'work', 'other'
  final bool isPrimary;
  final String? notes;

  PhoneNumber({
    required this.id,
    required this.phoneNumber,
    required this.phoneType,
    required this.isPrimary,
    this.notes,
  });

  factory PhoneNumber.fromJson(Map<String, dynamic> json) {
    String toString(dynamic value) {
      if (value is String) return value;
      return value.toString();
    }

    return PhoneNumber(
      id: json['id'] as int,
      phoneNumber: toString(json['phone_number']),
      phoneType: json['phone_type'] is String
          ? (json['phone_type'] as String?) ?? 'mobile'
          : (json['phone_type']?.toString() ?? 'mobile'),
      isPrimary: json['is_primary'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'phone_type': phoneType,
      'is_primary': isPrimary,
      'notes': notes,
    };
  }
}

/// Result of POST /clients/ including optional urgent soft-warning from the API.
class CreateLeadResult {
  final LeadModel lead;
  final String? urgentAssignmentWarning;

  const CreateLeadResult({
    required this.lead,
    this.urgentAssignmentWarning,
  });
}
