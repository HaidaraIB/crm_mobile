import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';

class Country {
  final String code;
  final String name;
  final String nameAr;
  final String dialCode;
  final String flag;

  Country({
    required this.code,
    required this.name,
    required this.nameAr,
    required this.dialCode,
    required this.flag,
  });
}

class PhoneInput extends StatefulWidget {
  final String? value;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final bool error;
  /// Optional message shown under the input when invalid.
  final String? errorText;
  final String? defaultCountry;

  const PhoneInput({
    super.key,
    this.value,
    this.onChanged,
    this.hintText,
    this.error = false,
    this.errorText,
    this.defaultCountry,
  });

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  final List<Country> _countries = [
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

  Country? _selectedCountry;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCountry();
    _parsePhoneNumber();
  }

  @override
  void didUpdateWidget(PhoneInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _parsePhoneNumber();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeCountry() {
    final defaultCode = widget.defaultCountry ?? 'IQ';
    _selectedCountry = _countries.firstWhere(
      (c) => c.code == defaultCode,
      orElse: () => _countries.first,
    );
  }

  void _parsePhoneNumber() {
    if (widget.value != null && widget.value!.isNotEmpty) {
      // Try to find country by dial code
      Country? foundCountry;
      for (var country in _countries) {
        if (widget.value!.startsWith(country.dialCode)) {
          foundCountry = country;
          break;
        }
      }

      if (foundCountry != null) {
        _selectedCountry = foundCountry;
        final phoneNumber = widget.value!.replaceFirst(foundCountry.dialCode, '').trim();
        _phoneController.text = phoneNumber;
      } else {
        // If no country code found, just show the number
        _phoneController.text = widget.value!.replaceAll(RegExp(r'[^0-9]'), '');
      }
    } else {
      _phoneController.clear();
    }
  }

  void _onPhoneChanged(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    _phoneController.value = TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
    _notifyChange();
  }

  void _onCountryChanged(Country country) {
    setState(() {
      _selectedCountry = country;
    });
    _notifyChange();
  }

  void _notifyChange() {
    if (_selectedCountry != null) {
      final fullNumber = _selectedCountry!.dialCode + _phoneController.text;
      widget.onChanged?.call(fullNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isRTL = localizations?.isRTL ?? false;
    final theme = Theme.of(context);
    final showError = widget.error ||
        (widget.errorText != null && widget.errorText!.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.ltr, // Force LTR for phone input
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: showError ? Colors.red : Colors.grey,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Country Code Dropdown
                _buildCountryDropdown(context, localizations, theme),
                // Divider
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                // Phone Number Input
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: widget.hintText ??
                          localizations?.translate('enterPhoneNumber') ??
                          'Enter phone number',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    onChanged: _onPhoneChanged,
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.errorText != null && widget.errorText!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _showCountryPicker(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations?.translate('selectCountry') ?? 'Select Country',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Countries List
            Expanded(
              child: ListView.builder(
                itemCount: _countries.length,
                itemBuilder: (context, index) {
                  final country = _countries[index];
                  final isSelected = _selectedCountry?.code == country.code;
                  return InkWell(
                    onTap: () {
                      _onCountryChanged(country);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: isSelected
                          ? theme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              localizations?.isRTL == true
                                  ? country.nameAr
                                  : country.name,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            country.dialCode,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.check,
                                color: theme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryDropdown(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    if (_selectedCountry == null) return const SizedBox();

    return InkWell(
      onTap: () => _showCountryPicker(context, localizations, theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCountry!.flag,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 4),
            Text(
              _selectedCountry!.dialCode,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
