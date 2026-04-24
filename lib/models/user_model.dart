class UserModel {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? name;
  final String role; // 'ADMIN', 'SUPERVISOR', 'EMPLOYEE', 'Owner', 'admin', 'supervisor', 'Employee'
  final String phone;
  final String? avatar;
  final String? profilePhoto;
  final String? email;
  final String? username;
  final CompanyModel? company;
  final bool? emailVerified;
  /// When role is supervisor, permissions from API (supervisor_permissions.permissions).
  final Map<String, bool>? supervisorPermissions;
  final bool? supervisorIsActive;
  /// User preferred language (ar/en), synced with API for emails and UI.
  final String? language;

  UserModel({
    required this.id,
    this.firstName,
    this.lastName,
    this.name,
    required this.role,
    required this.phone,
    this.avatar,
    this.profilePhoto,
    this.email,
    this.username,
    this.company,
    this.emailVerified,
    this.supervisorPermissions,
    this.supervisorIsActive,
    this.language,
  });

  // Check if user is admin (handles multiple role formats)
  bool get isAdmin {
    final roleLower = role.toLowerCase();
    return roleLower == 'admin' || roleLower == 'owner';
  }

  // Check if user is supervisor
  bool get isSupervisor {
    final roleLower = role.toLowerCase();
    return roleLower == 'supervisor';
  }

  // Check if user is employee (sales); excludes data_entry.
  bool get isEmployee {
    final roleLower = role.toLowerCase();
    return roleLower == 'employee';
  }

  /// Lead intake role: list/create/import only (API: `data_entry`).
  bool get isDataEntry {
    final roleLower = role.toLowerCase();
    return roleLower == 'data_entry';
  }

  /// True if user is supervisor, active, and has the given permission.
  bool hasSupervisorPermission(String key) {
    if (!isSupervisor || supervisorIsActive != true) return false;
    final perms = supervisorPermissions;
    if (perms == null) return false;
    return perms[key] == true;
  }

  // Get normalized role (ADMIN, SUPERVISOR, EMPLOYEE, or DATA_ENTRY)
  String get normalizedRole {
    if (isAdmin) return 'ADMIN';
    if (isSupervisor) return 'SUPERVISOR';
    if (isDataEntry) return 'DATA_ENTRY';
    return 'EMPLOYEE';
  }
  
  String get displayName {
    if (firstName != null || lastName != null) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return name ?? username ?? email ?? 'User $id';
  }
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    CompanyModel? company;
    
    // Handle company field - it can be an int (ID) or a Map (full object)
    if (json['company'] != null) {
      if (json['company'] is Map<String, dynamic>) {
        // Full company object
        company = CompanyModel.fromJson(json['company'] as Map<String, dynamic>);
      } else     if (json['company'] is int) {
        // Company ID only - create a minimal company object from available fields
        final companyId = json['company'] as int;
        final companyName = json['company_name'] as String? ?? '';
        final companySpecialization = json['company_specialization'] as String? ?? 'real_estate';

        company = CompanyModel(
          id: companyId,
          name: companyName,
          specialization: companySpecialization,
        );
      }
    }

    Map<String, bool>? supervisorPermissions;
    bool? supervisorIsActive;
    if (json['supervisor_permissions'] != null) {
      final sp = json['supervisor_permissions'] as Map<String, dynamic>;
      supervisorIsActive = sp['is_active'] as bool?;
      if (sp['permissions'] is Map<String, dynamic>) {
        final p = sp['permissions'] as Map<String, dynamic>;
        supervisorPermissions = p.map((k, v) => MapEntry(k, v == true));
      }
    }

    return UserModel(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? json['firstName'] as String?,
      lastName: json['last_name'] as String? ?? json['lastName'] as String?,
      name: json['name'] as String?,
      role: json['role'] as String? ?? 'Employee',
      phone: json['phone'] as String? ?? '',
      avatar: json['avatar'] as String?,
      profilePhoto: json['profile_photo'] as String? ?? json['profilePhoto'] as String?,
      email: json['email'] as String?,
      username: json['username'] as String?,
      company: company,
      emailVerified: json['email_verified'] as bool? ?? json['emailVerified'] as bool?,
      supervisorPermissions: supervisorPermissions,
      supervisorIsActive: supervisorIsActive,
      language: (json['language'] as String?)?.isNotEmpty == true && (json['language'] == 'ar' || json['language'] == 'en') ? json['language'] as String : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'name': name,
      'role': role,
      'phone': phone,
      'avatar': avatar,
      'profile_photo': profilePhoto,
      'email': email,
      'username': username,
      'company': company?.toJson(),
      'email_verified': emailVerified,
      if (supervisorPermissions != null) 'supervisor_permissions': {'is_active': supervisorIsActive, 'permissions': supervisorPermissions},
      if (language != null) 'language': language,
    };
  }
}

class CompanyModel {
  final int id;
  final String name;
  final String? domain;
  final String specialization; // 'real_estate', 'services', 'products'
  final bool? autoAssignEnabled;
  final bool? reAssignEnabled;
  final int? reAssignHours;
  final SubscriptionModel? subscription;
  
  CompanyModel({
    required this.id,
    required this.name,
    this.domain,
    required this.specialization,
    this.autoAssignEnabled,
    this.reAssignEnabled,
    this.reAssignHours,
    this.subscription,
  });
  
  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      domain: json['domain'] as String?,
      specialization: json['specialization'] as String? ?? 'real_estate',
      autoAssignEnabled: json['auto_assign_enabled'] as bool? ?? json['autoAssignEnabled'] as bool?,
      reAssignEnabled: json['re_assign_enabled'] as bool? ?? json['reAssignEnabled'] as bool?,
      reAssignHours: json['re_assign_hours'] as int? ?? json['reAssignHours'] as int?,
      subscription: json['subscription'] != null
          ? SubscriptionModel.fromJson(json['subscription'] as Map<String, dynamic>)
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'domain': domain,
      'specialization': specialization,
      'auto_assign_enabled': autoAssignEnabled,
      're_assign_enabled': reAssignEnabled,
      're_assign_hours': reAssignHours,
      'subscription': subscription?.toJson(),
    };
  }
}

class SubscriptionModel {
  final int id;
  final bool isActive;
  final String? startDate;
  final String? endDate;
  final PlanModel? plan;
  
  SubscriptionModel({
    required this.id,
    required this.isActive,
    this.startDate,
    this.endDate,
    this.plan,
  });
  
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as int,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? false,
      startDate: json['start_date'] as String? ?? json['startDate'] as String?,
      endDate: json['end_date'] as String? ?? json['endDate'] as String?,
      plan: json['plan'] != null
          ? PlanModel.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_active': isActive,
      'start_date': startDate,
      'end_date': endDate,
      'plan': plan?.toJson(),
    };
  }
}

class PlanModel {
  final int id;
  final String? name;
  final String? nameAr;
  
  PlanModel({
    required this.id,
    this.name,
    this.nameAr,
  });
  
  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as int,
      name: json['name'] as String?,
      nameAr: json['name_ar'] as String? ?? json['nameAr'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
    };
  }
}


