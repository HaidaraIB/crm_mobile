// Real Estate Models
class Developer {
  final int id;
  final String code;
  final String name;

  Developer({
    required this.id,
    required this.code,
    required this.name,
  });

  factory Developer.fromJson(Map<String, dynamic> json) {
    return Developer(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
    };
  }
}

class Project {
  final int id;
  final String code;
  final String name;
  final String developer;
  final String? type;
  final String? city;
  final String? paymentMethod;

  Project({
    required this.id,
    required this.code,
    required this.name,
    required this.developer,
    this.type,
    this.city,
    this.paymentMethod,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    String developerName = '';
    if (json['developer'] != null) {
      if (json['developer'] is String) {
        developerName = json['developer'] as String;
      } else if (json['developer'] is Map) {
        developerName = (json['developer'] as Map<String, dynamic>)['name'] as String? ?? '';
      } else if (json['developer'] is int) {
        // If it's just an ID, we can't get the name, so use empty string
        developerName = '';
      }
    }
    
    return Project(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      developer: developerName,
      type: json['type'] as String?,
      city: json['city'] as String?,
      paymentMethod: json['payment_method'] as String? ?? json['paymentMethod'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'developer': developer,
      'type': type,
      'city': city,
      'payment_method': paymentMethod,
    };
  }
}

class Unit {
  final int id;
  final String code;
  final String name;
  final String project;
  final int bedrooms;
  final int bathrooms;
  final double price;
  final String? type;
  final String? finishing;
  final String? city;
  final String? district;
  final String? zone;
  final bool isSold;

  Unit({
    required this.id,
    required this.code,
    required this.name,
    required this.project,
    required this.bedrooms,
    required this.bathrooms,
    required this.price,
    this.type,
    this.finishing,
    this.city,
    this.district,
    this.zone,
    required this.isSold,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    String projectName = '';
    if (json['project'] != null) {
      if (json['project'] is String) {
        projectName = json['project'] as String;
      } else if (json['project'] is Map) {
        projectName = (json['project'] as Map<String, dynamic>)['name'] as String? ?? '';
      } else if (json['project'] is int) {
        // If it's just an ID, we can't get the name, so use empty string
        projectName = '';
      }
    }
    
    // Helper function to safely parse numbers from various types
    int parseToInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? 0;
      }
      return 0;
    }
    
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
    
    return Unit(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      project: projectName,
      bedrooms: parseToInt(json['bedrooms']),
      bathrooms: parseToInt(json['bathrooms']),
      price: parseToDouble(json['price']),
      type: json['type'] as String?,
      finishing: json['finishing'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      zone: json['zone'] as String?,
      isSold: json['is_sold'] as bool? ?? json['isSold'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'project': project,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'price': price,
      'type': type,
      'finishing': finishing,
      'city': city,
      'district': district,
      'zone': zone,
      'is_sold': isSold,
    };
  }
}

class Owner {
  final int id;
  final String code;
  final String name;
  final String phone;
  final String? city;
  final String? district;

  Owner({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    this.city,
    this.district,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String?,
      district: json['district'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'phone': phone,
      'city': city,
      'district': district,
    };
  }
}

// Services Models
class Service {
  final int id;
  final String code;
  final String name;
  final String? description;
  final double price;
  final String? duration;
  final String category;
  final String? provider;
  final bool isActive;

  Service({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.price,
    this.duration,
    required this.category,
    this.provider,
    required this.isActive,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    String categoryName = '';
    if (json['category'] != null) {
      if (json['category'] is String) {
        categoryName = json['category'] as String;
      } else if (json['category'] is Map) {
        categoryName = (json['category'] as Map<String, dynamic>)['name'] as String? ?? '';
      } else if (json['category'] is int) {
        categoryName = '';
      }
    }
    
    String? providerName;
    if (json['provider'] != null) {
      if (json['provider'] is String) {
        providerName = json['provider'] as String;
      } else if (json['provider'] is Map) {
        providerName = (json['provider'] as Map<String, dynamic>)['name'] as String?;
      } else if (json['provider'] is int) {
        providerName = null;
      }
    }
    
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
    
    return Service(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: parseToDouble(json['price']),
      duration: json['duration'] as String?,
      category: categoryName,
      provider: providerName,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'price': price,
      'duration': duration,
      'category': category,
      'provider': provider,
      'is_active': isActive,
    };
  }
}

class ServicePackage {
  final int id;
  final String code;
  final String name;
  final String? description;
  final double price;
  final String? duration;
  final List<int> services; // Service IDs
  final bool isActive;

  ServicePackage({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.price,
    this.duration,
    required this.services,
    required this.isActive,
  });

  factory ServicePackage.fromJson(Map<String, dynamic> json) {
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
    
    // Parse services list - handle both int IDs and objects
    List<int> servicesList = [];
    if (json['services'] is List) {
      servicesList = (json['services'] as List).map((e) {
        if (e is int) return e;
        if (e is Map && e['id'] != null) {
          if (e['id'] is int) return e['id'] as int;
          if (e['id'] is String) {
            final parsed = int.tryParse(e['id'] as String);
            return parsed ?? 0;
          }
        }
        return 0;
      }).where((id) => id > 0).toList();
    }
    
    return ServicePackage(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: parseToDouble(json['price']),
      duration: json['duration'] as String?,
      services: servicesList,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'price': price,
      'duration': duration,
      'services': services,
      'is_active': isActive,
    };
  }
}

class ServiceProvider {
  final int id;
  final String code;
  final String name;
  final String phone;
  final String? email;
  final String? specialization;
  final double? rating;

  ServiceProvider({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    this.email,
    this.specialization,
    this.rating,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse doubles from various types
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
    
    return ServiceProvider(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      specialization: json['specialization'] as String?,
      rating: parseToDoubleNullable(json['rating']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'phone': phone,
      'email': email,
      'specialization': specialization,
      'rating': rating,
    };
  }
}

// Products Models
class Product {
  final int id;
  final String code;
  final String name;
  final String? description;
  final double price;
  final double cost;
  final int stock;
  final String category;
  final String? supplier;
  final String? sku;
  final String? image;
  final bool isActive;

  Product({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.price,
    required this.cost,
    required this.stock,
    required this.category,
    this.supplier,
    this.sku,
    this.image,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    String categoryName = '';
    if (json['category'] != null) {
      if (json['category'] is String) {
        categoryName = json['category'] as String;
      } else if (json['category'] is Map) {
        categoryName = (json['category'] as Map<String, dynamic>)['name'] as String? ?? '';
      } else if (json['category'] is int) {
        categoryName = '';
      }
    }
    
    String? supplierName;
    if (json['supplier'] != null) {
      if (json['supplier'] is String) {
        supplierName = json['supplier'] as String;
      } else if (json['supplier'] is Map) {
        supplierName = (json['supplier'] as Map<String, dynamic>)['name'] as String?;
      } else if (json['supplier'] is int) {
        supplierName = null;
      }
    }
    
    // Helper functions to safely parse numbers from various types
    int parseToInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? 0;
      }
      return 0;
    }
    
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
    
    return Product(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: parseToDouble(json['price']),
      cost: parseToDouble(json['cost']),
      stock: parseToInt(json['stock']),
      category: categoryName,
      supplier: supplierName,
      sku: json['sku'] as String?,
      image: json['image'] as String?,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'stock': stock,
      'category': category,
      'supplier': supplier,
      'sku': sku,
      'image': image,
      'is_active': isActive,
    };
  }
}

class ProductCategory {
  final int id;
  final String code;
  final String name;
  final String? description;
  final int? parentCategory;

  ProductCategory({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.parentCategory,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      parentCategory: json['parent_category'] as int? ?? json['parentCategory'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'parent_category': parentCategory,
    };
  }
}

class Supplier {
  final int id;
  final String code;
  final String name;
  final String? logo;
  final String phone;
  final String? email;
  final String? address;
  final String? contactPerson;
  final String? specialization;

  Supplier({
    required this.id,
    required this.code,
    required this.name,
    this.logo,
    required this.phone,
    this.email,
    this.address,
    this.contactPerson,
    this.specialization,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      logo: json['logo'] as String?,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String?,
      contactPerson: json['contact_person'] as String? ?? json['contactPerson'] as String?,
      specialization: json['specialization'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'logo': logo,
      'phone': phone,
      'email': email,
      'address': address,
      'contact_person': contactPerson,
      'specialization': specialization,
    };
  }
}

