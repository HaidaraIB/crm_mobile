import 'package:flutter/material.dart';
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';
import '../core/constants/countries.dart';
import '../core/localization/app_localizations.dart';

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
    if (oldWidget.defaultCountry != widget.defaultCountry &&
        (widget.value == null || widget.value!.isEmpty)) {
      _initializeCountry();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeCountry() {
    _selectedCountry = getCountryByCode(widget.defaultCountry ?? 'IQ');
  }

  void _parsePhoneNumber() {
    if (widget.value != null && widget.value!.isNotEmpty) {
      final matched = matchCountryByPhone(widget.value!);
      if (matched != null) {
        _selectedCountry = matched.country;
        _phoneController.text = matched.national;
      } else {
        _phoneController.text =
            widget.value!.replaceAll(RegExp(r'[^0-9]'), '');
      }
    } else {
      _phoneController.clear();
      _initializeCountry();
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
    final theme = Theme.of(context);
    final showError = widget.error ||
        (widget.errorText != null && widget.errorText!.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: showError
                    ? Colors.red
                    : (theme.dividerColor.withValues(alpha: 0.6)),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildCountryDropdown(context, localizations, theme),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: AutoDirTextField(
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
                    textDirection: TextDirection.ltr,
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

  void _showCountryPicker(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    final isRtl = localizations?.isRTL == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = filterCountries(query, isRtl: isRtl);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              localizations?.translate('selectCountry') ??
                                  'Select Country',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        autofocus: true,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText:
                              localizations?.translate('searchCountries') ??
                                  'Search countries…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) {
                          setSheetState(() => query = value);
                        },
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                '—',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final country = filtered[index];
                                final isSelected =
                                    _selectedCountry?.code == country.code;
                                return InkWell(
                                  onTap: () {
                                    _onCountryChanged(country);
                                    Navigator.pop(sheetContext);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    color: isSelected
                                        ? theme.primaryColor
                                            .withValues(alpha: 0.1)
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
                                            isRtl
                                                ? country.nameAr
                                                : country.name,
                                            style: theme.textTheme.bodyLarge,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          country.dialCode,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
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
          },
        );
      },
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
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCountry!.flag,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 6),
            Text(
              _selectedCountry!.dialCode,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: theme.iconTheme.color?.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
