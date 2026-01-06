class UserModel {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? name;
  final String role; // 'ADMIN', 'EMPLOYEE', 'Owner', 'admin', 'Employee' (handles both formats)
  final String phone;
  final String? avatar;
  final String? profilePhoto;
  final String? email;
  final String? username;
  final CompanyModel? company;
  final bool? emailVerified;
  
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
  });
  
  // Check if user is admin (handles multiple role formats)
  bool get isAdmin {
    final roleLower = role.toLowerCase();
    return roleLower == 'admin' || roleLower == 'owner';
  }
  
  // Check if user is employee
  bool get isEmployee {
    final roleLower = role.toLowerCase();
    return roleLower == 'employee';
  }
  
  // Get normalized role (ADMIN or EMPLOYEE)
  String get normalizedRole {
    return isAdmin ? 'ADMIN' : 'EMPLOYEE';
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
      } else if (json['company'] is int) {
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


