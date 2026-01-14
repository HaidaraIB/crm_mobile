// Settings Models for Channels, Stages, and Statuses

class ChannelModel {
  final int id;
  final String name;
  final String type; // 'Web', 'Social', 'Advertising', 'Email', 'Phone', 'SMS', 'WhatsApp', etc.
  final String priority; // 'High', 'Medium', 'Low'
  
  ChannelModel({
    required this.id,
    required this.name,
    required this.type,
    required this.priority,
  });
  
  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      priority: json['priority'] as String? ?? 'Medium',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'priority': priority,
    };
  }
  
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'type': type,
      'priority': priority,
    };
  }
  
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'type': type,
      'priority': priority,
    };
  }
}

class StageModel {
  final int id;
  final String name;
  final String? description;
  final String color; // Hex color code
  final bool required;
  final bool autoAdvance;
  
  StageModel({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    required this.required,
    required this.autoAdvance,
  });
  
  factory StageModel.fromJson(Map<String, dynamic> json) {
    return StageModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as String? ?? '#808080',
      required: json['required'] as bool? ?? false,
      autoAdvance: json['auto_advance'] as bool? ?? json['autoAdvance'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'required': required,
      'auto_advance': autoAdvance,
    };
  }
  
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'required': required,
      'auto_advance': autoAdvance,
    };
  }
  
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'required': required,
      'auto_advance': autoAdvance,
    };
  }
}

class StatusModel {
  final int id;
  final String name;
  final String? description;
  final String category; // 'Active', 'Inactive', 'Follow Up', 'Closed'
  final String color; // Hex color code
  final bool isDefault;
  final bool isHidden;
  
  StatusModel({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.color,
    required this.isDefault,
    required this.isHidden,
  });
  
  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'Active',
      color: json['color'] as String? ?? '#808080',
      isDefault: json['is_default'] as bool? ?? json['isDefault'] as bool? ?? false,
      isHidden: json['is_hidden'] as bool? ?? json['isHidden'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'color': color,
      'is_default': isDefault,
      'is_hidden': isHidden,
    };
  }
  
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'color': color,
      'is_default': isDefault,
      'is_hidden': isHidden,
    };
  }
  
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'color': color,
      'is_default': isDefault,
      'is_hidden': isHidden,
    };
  }
}

class CallMethodModel {
  final int id;
  final String name;
  final String? description;
  final String color; // Hex color code
  
  CallMethodModel({
    required this.id,
    required this.name,
    this.description,
    required this.color,
  });
  
  factory CallMethodModel.fromJson(Map<String, dynamic> json) {
    return CallMethodModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as String? ?? '#808080',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
    };
  }
  
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
    };
  }
  
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
    };
  }
}

