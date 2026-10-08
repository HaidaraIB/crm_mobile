// Dial-code country list for PhoneInput.
// Keep in sync with CRM-project/utils/countries.ts and CRM-admin-panel/utils/countries.ts.

class Country {
  final String code;
  final String name;
  final String nameAr;
  final String dialCode;
  final String flag;

  const Country({
    required this.code,
    required this.name,
    required this.nameAr,
    required this.dialCode,
    required this.flag,
  });
}

const List<Country> kCountries = [
  Country(code: 'SY', name: 'Syria', nameAr: 'سوريا', dialCode: '+963', flag: '🇸🇾'),
  Country(code: 'IQ', name: 'Iraq', nameAr: 'العراق', dialCode: '+964', flag: '🇮🇶'),
  Country(code: 'SA', name: 'Saudi Arabia', nameAr: 'السعودية', dialCode: '+966', flag: '🇸🇦'),
  Country(code: 'AE', name: 'United Arab Emirates', nameAr: 'الإمارات', dialCode: '+971', flag: '🇦🇪'),
  Country(code: 'KW', name: 'Kuwait', nameAr: 'الكويت', dialCode: '+965', flag: '🇰🇼'),
  Country(code: 'QA', name: 'Qatar', nameAr: 'قطر', dialCode: '+974', flag: '🇶🇦'),
  Country(code: 'BH', name: 'Bahrain', nameAr: 'البحرين', dialCode: '+973', flag: '🇧🇭'),
  Country(code: 'OM', name: 'Oman', nameAr: 'عمان', dialCode: '+968', flag: '🇴🇲'),
  Country(code: 'JO', name: 'Jordan', nameAr: 'الأردن', dialCode: '+962', flag: '🇯🇴'),
  Country(code: 'LB', name: 'Lebanon', nameAr: 'لبنان', dialCode: '+961', flag: '🇱🇧'),
  Country(code: 'EG', name: 'Egypt', nameAr: 'مصر', dialCode: '+20', flag: '🇪🇬'),
  Country(code: 'YE', name: 'Yemen', nameAr: 'اليمن', dialCode: '+967', flag: '🇾🇪'),
  Country(code: 'PS', name: 'Palestine', nameAr: 'فلسطين', dialCode: '+970', flag: '🇵🇸'),
  Country(code: 'MA', name: 'Morocco', nameAr: 'المغرب', dialCode: '+212', flag: '🇲🇦'),
  Country(code: 'DZ', name: 'Algeria', nameAr: 'الجزائر', dialCode: '+213', flag: '🇩🇿'),
  Country(code: 'TN', name: 'Tunisia', nameAr: 'تونس', dialCode: '+216', flag: '🇹🇳'),
  Country(code: 'LY', name: 'Libya', nameAr: 'ليبيا', dialCode: '+218', flag: '🇱🇾'),
  Country(code: 'SD', name: 'Sudan', nameAr: 'السودان', dialCode: '+249', flag: '🇸🇩'),
  Country(code: 'SO', name: 'Somalia', nameAr: 'الصومال', dialCode: '+252', flag: '🇸🇴'),
  Country(code: 'DJ', name: 'Djibouti', nameAr: 'جيبوتي', dialCode: '+253', flag: '🇩🇯'),
  Country(code: 'MR', name: 'Mauritania', nameAr: 'موريتانيا', dialCode: '+222', flag: '🇲🇷'),
  Country(code: 'US', name: 'United States', nameAr: 'الولايات المتحدة', dialCode: '+1', flag: '🇺🇸'),
  Country(code: 'CA', name: 'Canada', nameAr: 'كندا', dialCode: '+1', flag: '🇨🇦'),
  Country(code: 'GB', name: 'United Kingdom', nameAr: 'المملكة المتحدة', dialCode: '+44', flag: '🇬🇧'),
  Country(code: 'IE', name: 'Ireland', nameAr: 'أيرلندا', dialCode: '+353', flag: '🇮🇪'),
  Country(code: 'FR', name: 'France', nameAr: 'فرنسا', dialCode: '+33', flag: '🇫🇷'),
  Country(code: 'DE', name: 'Germany', nameAr: 'ألمانيا', dialCode: '+49', flag: '🇩🇪'),
  Country(code: 'IT', name: 'Italy', nameAr: 'إيطاليا', dialCode: '+39', flag: '🇮🇹'),
  Country(code: 'ES', name: 'Spain', nameAr: 'إسبانيا', dialCode: '+34', flag: '🇪🇸'),
  Country(code: 'PT', name: 'Portugal', nameAr: 'البرتغال', dialCode: '+351', flag: '🇵🇹'),
  Country(code: 'NL', name: 'Netherlands', nameAr: 'هولندا', dialCode: '+31', flag: '🇳🇱'),
  Country(code: 'BE', name: 'Belgium', nameAr: 'بلجيكا', dialCode: '+32', flag: '🇧🇪'),
  Country(code: 'CH', name: 'Switzerland', nameAr: 'سويسرا', dialCode: '+41', flag: '🇨🇭'),
  Country(code: 'AT', name: 'Austria', nameAr: 'النمسا', dialCode: '+43', flag: '🇦🇹'),
  Country(code: 'SE', name: 'Sweden', nameAr: 'السويد', dialCode: '+46', flag: '🇸🇪'),
  Country(code: 'NO', name: 'Norway', nameAr: 'النرويج', dialCode: '+47', flag: '🇳🇴'),
  Country(code: 'DK', name: 'Denmark', nameAr: 'الدنمارك', dialCode: '+45', flag: '🇩🇰'),
  Country(code: 'FI', name: 'Finland', nameAr: 'فنلندا', dialCode: '+358', flag: '🇫🇮'),
  Country(code: 'PL', name: 'Poland', nameAr: 'بولندا', dialCode: '+48', flag: '🇵🇱'),
  Country(code: 'CZ', name: 'Czech Republic', nameAr: 'التشيك', dialCode: '+420', flag: '🇨🇿'),
  Country(code: 'GR', name: 'Greece', nameAr: 'اليونان', dialCode: '+30', flag: '🇬🇷'),
  Country(code: 'RU', name: 'Russia', nameAr: 'روسيا', dialCode: '+7', flag: '🇷🇺'),
  Country(code: 'UA', name: 'Ukraine', nameAr: 'أوكرانيا', dialCode: '+380', flag: '🇺🇦'),
  Country(code: 'IN', name: 'India', nameAr: 'الهند', dialCode: '+91', flag: '🇮🇳'),
  Country(code: 'PK', name: 'Pakistan', nameAr: 'باكستان', dialCode: '+92', flag: '🇵🇰'),
  Country(code: 'BD', name: 'Bangladesh', nameAr: 'بنغلاديش', dialCode: '+880', flag: '🇧🇩'),
  Country(code: 'AF', name: 'Afghanistan', nameAr: 'أفغانستان', dialCode: '+93', flag: '🇦🇫'),
  Country(code: 'TR', name: 'Turkey', nameAr: 'تركيا', dialCode: '+90', flag: '🇹🇷'),
  Country(code: 'IR', name: 'Iran', nameAr: 'إيران', dialCode: '+98', flag: '🇮🇷'),
  Country(code: 'CN', name: 'China', nameAr: 'الصين', dialCode: '+86', flag: '🇨🇳'),
  Country(code: 'JP', name: 'Japan', nameAr: 'اليابان', dialCode: '+81', flag: '🇯🇵'),
  Country(code: 'KR', name: 'South Korea', nameAr: 'كوريا الجنوبية', dialCode: '+82', flag: '🇰🇷'),
  Country(code: 'TH', name: 'Thailand', nameAr: 'تايلاند', dialCode: '+66', flag: '🇹🇭'),
  Country(code: 'VN', name: 'Vietnam', nameAr: 'فيتنام', dialCode: '+84', flag: '🇻🇳'),
  Country(code: 'ID', name: 'Indonesia', nameAr: 'إندونيسيا', dialCode: '+62', flag: '🇮🇩'),
  Country(code: 'MY', name: 'Malaysia', nameAr: 'ماليزيا', dialCode: '+60', flag: '🇲🇾'),
  Country(code: 'SG', name: 'Singapore', nameAr: 'سنغافورة', dialCode: '+65', flag: '🇸🇬'),
  Country(code: 'PH', name: 'Philippines', nameAr: 'الفلبين', dialCode: '+63', flag: '🇵🇭'),
  Country(code: 'AU', name: 'Australia', nameAr: 'أستراليا', dialCode: '+61', flag: '🇦🇺'),
  Country(code: 'NZ', name: 'New Zealand', nameAr: 'نيوزيلندا', dialCode: '+64', flag: '🇳🇿'),
  Country(code: 'ZA', name: 'South Africa', nameAr: 'جنوب أفريقيا', dialCode: '+27', flag: '🇿🇦'),
  Country(code: 'NG', name: 'Nigeria', nameAr: 'نيجيريا', dialCode: '+234', flag: '🇳🇬'),
  Country(code: 'KE', name: 'Kenya', nameAr: 'كينيا', dialCode: '+254', flag: '🇰🇪'),
  Country(code: 'GH', name: 'Ghana', nameAr: 'غانا', dialCode: '+233', flag: '🇬🇭'),
  Country(code: 'ET', name: 'Ethiopia', nameAr: 'إثيوبيا', dialCode: '+251', flag: '🇪🇹'),
  Country(code: 'BR', name: 'Brazil', nameAr: 'البرازيل', dialCode: '+55', flag: '🇧🇷'),
  Country(code: 'MX', name: 'Mexico', nameAr: 'المكسيك', dialCode: '+52', flag: '🇲🇽'),
  Country(code: 'AR', name: 'Argentina', nameAr: 'الأرجنتين', dialCode: '+54', flag: '🇦🇷'),
  Country(code: 'CO', name: 'Colombia', nameAr: 'كولومبيا', dialCode: '+57', flag: '🇨🇴'),
  Country(code: 'CL', name: 'Chile', nameAr: 'تشيلي', dialCode: '+56', flag: '🇨🇱'),
  Country(code: 'PE', name: 'Peru', nameAr: 'بيرو', dialCode: '+51', flag: '🇵🇪'),
  Country(code: 'VE', name: 'Venezuela', nameAr: 'فنزويلا', dialCode: '+58', flag: '🇻🇪'),
  Country(code: 'EC', name: 'Ecuador', nameAr: 'الإكوادور', dialCode: '+593', flag: '🇪🇨'),
];

/// Countries sorted by dial-code length descending for longest-prefix matching.
final List<Country> _byDialLength = List<Country>.from(kCountries)
  ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

Country getCountryByCode(String code, {String fallback = 'IQ'}) {
  return kCountries.firstWhere(
    (c) => c.code == code,
    orElse: () => kCountries.firstWhere(
      (c) => c.code == fallback,
      orElse: () => kCountries.first,
    ),
  );
}

/// Match E.164 value to the longest dial-code prefix.
({Country country, String national})? matchCountryByPhone(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  for (final country in _byDialLength) {
    if (trimmed.startsWith(country.dialCode)) {
      final national =
          trimmed.substring(country.dialCode.length).replaceAll(RegExp(r'\D'), '');
      return (country: country, national: national);
    }
  }
  return null;
}

List<Country> filterCountries(String query, {required bool isRtl}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCountries;
  return kCountries.where((c) {
    final name = (isRtl ? c.nameAr : c.name).toLowerCase();
    return name.contains(q) ||
        c.name.toLowerCase().contains(q) ||
        c.nameAr.contains(query.trim()) ||
        c.dialCode.contains(q) ||
        c.code.toLowerCase().contains(q);
  }).toList();
}
