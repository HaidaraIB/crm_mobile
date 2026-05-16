/// Clinical-catalog wording for `medical` specialization (services inventory API).
typedef InvTermMap = Map<String, String>;

final Map<String, Map<String, InvTermMap>> kInventoryTerminologyBySpec = {
  'medical': {
    'en': {
      'inventory': 'Clinical catalog',
      'services': 'Procedures',
      'servicePackages': 'Treatment packages',
      'serviceProviders': 'Doctors',
      'manageLeadsInventory': 'Manage patients and clinical catalog',
      'addService': 'Add procedure',
      'addServicePackage': 'Add treatment package',
      'addServiceProvider': 'Add doctor',
      'editService': 'Edit procedure',
      'editServicePackage': 'Edit treatment package',
      'editServiceProvider': 'Edit doctor',
      'noServicesFound': 'No procedures found',
      'noServicePackagesFound': 'No treatment packages found',
      'noServiceProvidersFound': 'No doctors found',
      'serviceDeleted': 'Procedure deleted',
      'serviceCreated': 'Procedure created successfully',
      'serviceUpdated': 'Procedure updated successfully',
      'deleteService': 'Delete procedure',
      'confirmDeleteService': 'Are you sure you want to delete the procedure',
      'deleteServicePackage': 'Delete treatment package',
      'confirmDeleteServicePackage':
          'Are you sure you want to delete the treatment package',
      'deleteServiceProvider': 'Delete doctor',
      'confirmDeleteServiceProvider':
          'Are you sure you want to delete the doctor',
      'serviceRequired': 'Procedure is required',
      'failedToLoadServices': 'Failed to load procedures',
      'failedToLoadServicePackages': 'Failed to load treatment packages',
      'failedToLoadServiceProviders': 'Failed to load doctors',
      'failedToCreateService': 'Failed to create procedure',
      'failedToUpdateService': 'Failed to update procedure',
      'failedToDeleteService': 'Failed to delete procedure',
      'failedToCreateServicePackage': 'Failed to create treatment package',
      'failedToUpdateServicePackage': 'Failed to update treatment package',
      'failedToDeleteServicePackage': 'Failed to delete treatment package',
      'failedToCreateServiceProvider': 'Failed to create doctor',
      'failedToUpdateServiceProvider': 'Failed to update doctor',
      'failedToDeleteServiceProvider': 'Failed to delete doctor',
    },
    'ar': {
      'inventory': 'الكتالوج الطبي',
      'services': 'الإجراءات',
      'servicePackages': 'باقات العلاج',
      'serviceProviders': 'الأطباء',
      'manageLeadsInventory': 'إدارة المرضى والكتالوج الطبي',
      'addService': 'إضافة إجراء',
      'addServicePackage': 'إضافة باقة علاج',
      'addServiceProvider': 'إضافة طبيب',
      'editService': 'تعديل إجراء',
      'editServicePackage': 'تعديل باقة علاج',
      'editServiceProvider': 'تعديل طبيب',
      'noServicesFound': 'لا توجد إجراءات',
      'noServicePackagesFound': 'لا توجد باقات علاج',
      'noServiceProvidersFound': 'لا يوجد أطباء',
      'serviceDeleted': 'تم حذف الإجراء',
      'serviceCreated': 'تم إنشاء الإجراء بنجاح',
      'serviceUpdated': 'تم تحديث الإجراء بنجاح',
      'deleteService': 'حذف الإجراء',
      'confirmDeleteService': 'هل أنت متأكد من حذف الإجراء',
      'deleteServicePackage': 'حذف باقة العلاج',
      'confirmDeleteServicePackage': 'هل أنت متأكد من حذف باقة العلاج',
      'deleteServiceProvider': 'حذف الطبيب',
      'confirmDeleteServiceProvider': 'هل أنت متأكد من حذف الطبيب',
      'serviceRequired': 'الإجراء مطلوب',
      'failedToLoadServices': 'فشل تحميل الإجراءات',
      'failedToLoadServicePackages': 'فشل تحميل باقات العلاج',
      'failedToLoadServiceProviders': 'فشل تحميل الأطباء',
      'failedToCreateService': 'فشل إنشاء الإجراء',
      'failedToUpdateService': 'فشل تحديث الإجراء',
      'failedToDeleteService': 'فشل حذف الإجراء',
      'failedToCreateServicePackage': 'فشل إنشاء باقة العلاج',
      'failedToUpdateServicePackage': 'فشل تحديث باقة العلاج',
      'failedToDeleteServicePackage': 'فشل حذف باقة العلاج',
      'failedToCreateServiceProvider': 'فشل إنشاء الطبيب',
      'failedToUpdateServiceProvider': 'فشل تحديث الطبيب',
      'failedToDeleteServiceProvider': 'فشل حذف الطبيب',
    },
  },
};

String? inventoryTerminologyLookup(
  String? specialization,
  String localeLang,
  String key,
) {
  final spec = (specialization ?? '').toLowerCase();
  final byLang = kInventoryTerminologyBySpec[spec];
  if (byLang == null) return null;
  final lang = localeLang == 'ar' ? 'ar' : 'en';
  final map = byLang[lang] ?? byLang['en'];
  if (map == null) return null;
  final v = map[key];
  if (v == null || v.isEmpty) return null;
  return v;
}
