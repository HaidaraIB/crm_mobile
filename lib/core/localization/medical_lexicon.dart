/// When the signed-in company has `medical` specialization, [AppLocalizations.translate]
/// applies overrides from [medical_translation_overrides.dart].
class MedicalLexicon {
  MedicalLexicon._();

  static String? _companySpecialization;

  static void setCompanySpecialization(String? specialization) {
    _companySpecialization = specialization;
  }

  static void clear() {
    _companySpecialization = null;
  }

  static String? get companySpecialization => _companySpecialization;

  static bool get isMedicalTenant =>
      (_companySpecialization ?? '').toLowerCase() == 'medical';
}

