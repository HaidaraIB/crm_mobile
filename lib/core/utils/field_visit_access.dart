import '../../models/user_model.dart';

/// True only when field visits are enabled for this company (admin + owner).
bool isFieldVisitAllowed(CompanyModel? company) {
  if (company == null) return false;
  if (company.fieldVisitAllowed != null) return company.fieldVisitAllowed!;
  if (company.fieldVisitAdminAllowed == false) return false;
  if (company.fieldVisitEnabled == false) return false;
  return true;
}
