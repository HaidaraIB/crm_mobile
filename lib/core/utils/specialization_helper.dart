import '../../models/user_model.dart';

/// Utility class for checking company specialization
class SpecializationHelper {
  /// Check if company specialization is real estate
  static bool isRealEstate(UserModel? user) {
    return user?.company?.specialization == 'real_estate';
  }
  
  /// Check if company specialization is services
  static bool isServices(UserModel? user) {
    return user?.company?.specialization == 'services';
  }
  
  /// Check if company specialization is products
  static bool isProducts(UserModel? user) {
    return user?.company?.specialization == 'products';
  }
  
  /// Get the current specialization from user
  static String? getSpecialization(UserModel? user) {
    return user?.company?.specialization;
  }
  
  /// Check if a feature should be enabled based on specialization
  static bool shouldEnableFeature(UserModel? user, String feature) {
    final specialization = getSpecialization(user);
    
    switch (feature) {
      case 'developers':
      case 'projects':
      case 'units':
      case 'owners':
      case 'properties':
        return specialization == 'real_estate';
      
      case 'services':
      case 'service_packages':
      case 'service_providers':
        return specialization == 'services';
      
      case 'products':
      case 'product_categories':
      case 'suppliers':
        return specialization == 'products';
      
      default:
        return false;
    }
  }
}

