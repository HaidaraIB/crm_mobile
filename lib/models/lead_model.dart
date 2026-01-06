class LeadModel {
  final int id;
  final String name;
  final String phone;
  final String? status;
  final String type; // 'Fresh', 'Cold', 'My', 'Rotated', 'All'
  final int assignedTo;
  final double budget;
  final String? communicationWay;
  final String? priority; // 'High', 'Medium', 'Low'
  final DateTime createdAt;
  final String? lastFeedback;
  final String? notes;
  final String? lastStage;
  final String? statusName;
  final List<PhoneNumber>? phoneNumbers;
  
  LeadModel({
    required this.id,
    required this.name,
    required this.phone,
    this.status,
    required this.type,
    required this.assignedTo,
    required this.budget,
    this.communicationWay,
    this.priority,
    required this.createdAt,
    this.lastFeedback,
    this.notes,
    this.lastStage,
    this.statusName,
    this.phoneNumbers,
  });
  
  factory LeadModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to String?
    String? toStringOrNull(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }
    
    // Helper function to safely convert to double
    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }
    
    // Helper function to safely convert to int
    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }
    
    // Handle status - it can be an int (ID) or null, convert to String if needed
    String? statusValue = toStringOrNull(json['status']);
    
    // Handle phone - check both 'phone' and 'phone_number' fields
    String? phoneValue = toStringOrNull(json['phone']) ?? toStringOrNull(json['phone_number']);
    
    // Handle communication_way - it can be an int (ID) or a string
    // If it's an ID, prefer the name from communication_way_name
    String? communicationWayValue = json['communication_way_name'] as String?;
    communicationWayValue ??= toStringOrNull(json['communication_way']) ?? toStringOrNull(json['communicationWay']);
    
    return LeadModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: phoneValue ?? '',
      status: statusValue,
      type: toStringOrNull(json['type']) ?? 'All',
      assignedTo: toInt(json['assigned_to'] ?? json['assignedTo'], 0),
      budget: toDouble(json['budget']),
      communicationWay: communicationWayValue,
      priority: toStringOrNull(json['priority']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : (json['createdAt'] != null 
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now()),
      lastFeedback: json['last_feedback'] as String? ?? json['lastFeedback'] as String?,
      notes: json['notes'] as String?,
      lastStage: json['last_stage'] as String? ?? json['lastStage'] as String?,
      statusName: json['status_name'] as String?,
      phoneNumbers: json['phone_numbers'] != null
          ? (json['phone_numbers'] as List)
              .map((e) => PhoneNumber.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
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
      'communication_way': communicationWay,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'last_feedback': lastFeedback,
      'notes': notes,
      'last_stage': lastStage,
      'status_name': statusName,
      'phone_numbers': phoneNumbers?.map((e) => e.toJson()).toList(),
    };
  }
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
    // Helper function to safely convert to String
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


