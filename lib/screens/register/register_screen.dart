import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/bloc/theme/theme_bloc.dart';
import '../../core/bloc/language/language_bloc.dart';
import '../../services/api_service.dart';
import '../../models/plan_model.dart';
import '../../widgets/phone_input.dart';
import '../../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/home_screen.dart';
import '../payment/subscription_payment_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0; // 0: Company, 1: Owner, 2: Plan
  
  // Company information
  final _companyNameController = TextEditingController();
  final _companyDomainController = TextEditingController();
  String _specialization = 'real_estate';
  
  // Owner information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Plan selection
  List<PlanModel> _plans = [];
  PlanModel? _selectedPlan;
  String _billingCycle = 'monthly';
  bool _plansLoading = true;
  String? _plansError;
  
  // UI state
  bool _isLoading = false;
  bool _stepCheckLoading = false;
  Map<String, String> _errors = {};
  String? _generalError;
  
  @override
  void initState() {
    super.initState();
    _loadPlans();
  }
  
  @override
  void dispose() {
    _companyNameController.dispose();
    _companyDomainController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPlans() async {
    setState(() {
      _plansLoading = true;
      _plansError = null;
    });
    
    try {
      final apiService = ApiService();
      final plansData = await apiService.getPublicPlans();
      final plans = plansData.map((json) => PlanModel.fromJson(json)).toList();
      
      if (mounted) {
        setState(() {
          _plans = plans;
          _plansLoading = false;
          if (plans.isNotEmpty) {
            _selectedPlan = plans.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _plansError = e.toString().replaceAll('Exception: ', '');
          _plansLoading = false;
        });
      }
    }
  }
  
  String? _validateCompanyName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)?.translate('companyNameRequired') ?? 
          'Company name is required';
    }
    return null;
  }
  
  String? _validateCompanyDomain(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)?.translate('companyDomainRequired') ?? 
          'Company domain is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.?[a-zA-Z0-9-]*[a-zA-Z0-9]*$')
        .hasMatch(value.trim())) {
      return AppLocalizations.of(context)?.translate('invalidDomain') ?? 
          'Invalid domain format';
    }
    return null;
  }
  
  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)?.translate('firstNameRequired') ?? 
          'First name is required';
    }
    return null;
  }
  
  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)?.translate('lastNameRequired') ?? 
          'Last name is required';
    }
    return null;
  }
  
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)?.translate('emailRequired') ?? 
          'Email is required';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return AppLocalizations.of(context)?.translate('invalidEmail') ?? 
          'Invalid email format';
    }
    return null;
  }
  
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)?.translate('usernameRequired') ?? 
          'Username is required';
    }
    if (value.trim().length < 3) {
      return AppLocalizations.of(context)?.translate('usernameMinLength') ?? 
          'Username must be at least 3 characters';
    }
    return null;
  }
  
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.translate('passwordRequired') ?? 
          'Password is required';
    }
    if (value.length < 8) {
      return AppLocalizations.of(context)?.translate('passwordMinLength') ?? 
          'Password must be at least 8 characters';
    }
    return null;
  }
  
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.translate('confirmPasswordRequired') ?? 
          'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return AppLocalizations.of(context)?.translate('passwordsDoNotMatch') ?? 
          'Passwords do not match';
    }
    return null;
  }
  
  Future<bool> _checkAvailability({
    String? companyDomain,
    String? email,
    String? username,
    String? phone,
  }) async {
    setState(() {
      _stepCheckLoading = true;
      _errors = {};
    });
    
    try {
      final apiService = ApiService();
      await apiService.checkRegistrationAvailability(
        companyDomain: companyDomain,
        email: email,
        username: username,
        phone: phone,
      );
      
      if (mounted) {
        setState(() {
          _stepCheckLoading = false;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        final exceptionString = e.toString();
        final cleanError = exceptionString.replaceAll('Exception: ', '');
        
        Map<String, String> fieldErrors = {};
        
        // Try to extract field errors from exception
        try {
          final dynamic error = e;
          if (error.fields != null) {
            final fields = error.fields as Map<String, dynamic>;
            fields.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                fieldErrors[key] = value.first.toString();
              } else if (value is String) {
                fieldErrors[key] = value;
              }
            });
          }
        } catch (_) {}
        
        // Map backend field names to frontend field names
        final mappedErrors = <String, String>{};
        if (fieldErrors.containsKey('company_domain')) {
          mappedErrors['companyDomain'] = fieldErrors['company_domain']!;
        }
        if (fieldErrors.containsKey('email')) {
          mappedErrors['email'] = fieldErrors['email']!;
        }
        if (fieldErrors.containsKey('username')) {
          mappedErrors['username'] = fieldErrors['username']!;
        }
        if (fieldErrors.containsKey('phone')) {
          mappedErrors['phone'] = fieldErrors['phone']!;
        }
        
        setState(() {
          _errors = mappedErrors;
          _stepCheckLoading = false;
          if (mappedErrors.isEmpty) {
            _generalError = cleanError;
          }
        });
      }
      return false;
    }
  }
  
  Future<void> _handleNext() async {
    if (_currentStep == 0) {
      // Validate step 1: Company information
      if (!_formKey.currentState!.validate()) {
        return;
      }
      
      final domainAvailable = await _checkAvailability(
        companyDomain: _companyDomainController.text.trim(),
      );
      
      if (domainAvailable) {
        setState(() {
          _currentStep = 1;
          _errors = {};
          _generalError = null;
        });
      }
    } else if (_currentStep == 1) {
      // Validate step 2: Owner information
      if (!_formKey.currentState!.validate()) {
        return;
      }
      
      final ownerAvailable = await _checkAvailability(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      
      if (ownerAvailable) {
        setState(() {
          _currentStep = 2;
          _errors = {};
          _generalError = null;
        });
      }
    }
  }
  
  /// Parse subscription id from API (may be int or string).
  int? _parseSubscriptionId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
  
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      // If validation fails, go back to step 2
      setState(() {
        _currentStep = 1;
      });
      return;
    }
    
    if (_selectedPlan == null) {
      setState(() {
        _generalError = AppLocalizations.of(context)?.translate('planRequired') ?? 
            'Please select a plan to continue';
        _currentStep = 2;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errors = {};
      _generalError = null;
    });
    
    try {
      final apiService = ApiService();
      final languageBloc = context.read<LanguageBloc>();
      final language = languageBloc.state.locale.languageCode;
      
      final response = await apiService.registerCompany(
        company: {
          'name': _companyNameController.text.trim(),
          'domain': _companyDomainController.text.trim(),
          'specialization': _specialization,
        },
        owner: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
          'phone': _phoneController.text.trim(),
        },
        planId: _selectedPlan!.id,
        billingCycle: _billingCycle,
        language: language,
      );
      
      // Save user data and tokens (already saved by registerCompany)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.currentUserKey, 
          jsonEncode(response['user']));
      await prefs.setBool(AppConstants.isLoggedInKey, true);
      
      if (mounted) {
        final requiresPayment = response['requires_payment'] == true;
        final subscription = response['subscription'] as Map<String, dynamic>?;
        final subscriptionId = subscription != null
            ? _parseSubscriptionId(subscription['id'])
            : null;
        
        if (requiresPayment && subscriptionId != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => SubscriptionPaymentScreen(
                subscriptionId: subscriptionId,
                planId: _selectedPlan!.id,
                billingCycle: _billingCycle,
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final exceptionString = e.toString();
        final cleanError = exceptionString.replaceAll('Exception: ', '');
        
        Map<String, String> fieldErrors = {};
        
        // Try to extract field errors from exception
        try {
          final dynamic error = e;
          if (error.fields != null) {
            final fields = error.fields as Map<String, dynamic>;
            
            // Map backend field names to frontend field names
            if (fields.containsKey('company')) {
              final companyErrors = fields['company'] as Map<String, dynamic>?;
              if (companyErrors != null) {
                if (companyErrors.containsKey('domain')) {
                  fieldErrors['companyDomain'] = companyErrors['domain'].toString();
                }
                if (companyErrors.containsKey('name')) {
                  fieldErrors['companyName'] = companyErrors['name'].toString();
                }
              }
            }
            
            if (fields.containsKey('owner')) {
              final ownerErrors = fields['owner'] as Map<String, dynamic>?;
              if (ownerErrors != null) {
                if (ownerErrors.containsKey('first_name')) {
                  fieldErrors['firstName'] = ownerErrors['first_name'].toString();
                }
                if (ownerErrors.containsKey('last_name')) {
                  fieldErrors['lastName'] = ownerErrors['last_name'].toString();
                }
                if (ownerErrors.containsKey('email')) {
                  fieldErrors['email'] = ownerErrors['email'].toString();
                }
                if (ownerErrors.containsKey('username')) {
                  fieldErrors['username'] = ownerErrors['username'].toString();
                }
                if (ownerErrors.containsKey('password')) {
                  fieldErrors['password'] = ownerErrors['password'].toString();
                }
                if (ownerErrors.containsKey('phone')) {
                  fieldErrors['phone'] = ownerErrors['phone'].toString();
                }
              }
            }
            
            // Direct field mappings
            if (fields.containsKey('email')) {
              fieldErrors['email'] = fields['email'].toString();
            }
            if (fields.containsKey('username')) {
              fieldErrors['username'] = fields['username'].toString();
            }
            if (fields.containsKey('password')) {
              fieldErrors['password'] = fields['password'].toString();
            }
            if (fields.containsKey('phone')) {
              fieldErrors['phone'] = fields['phone'].toString();
            }
            if (fields.containsKey('domain')) {
              fieldErrors['companyDomain'] = fields['domain'].toString();
            }
            if (fields.containsKey('name')) {
              fieldErrors['companyName'] = fields['name'].toString();
            }
          }
        } catch (_) {}
        
        // Determine which step to show based on errors
        int errorStep = 2;
        if (fieldErrors.containsKey('companyName') || 
            fieldErrors.containsKey('companyDomain')) {
          errorStep = 0;
        } else if (fieldErrors.containsKey('firstName') ||
            fieldErrors.containsKey('lastName') ||
            fieldErrors.containsKey('email') ||
            fieldErrors.containsKey('username') ||
            fieldErrors.containsKey('password') ||
            fieldErrors.containsKey('phone')) {
          errorStep = 1;
        }
        
        setState(() {
          _errors = fieldErrors;
          _generalError = fieldErrors.isEmpty ? cleanError : null;
          _currentStep = errorStep;
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final themeBloc = context.read<ThemeBloc>();
    final languageBloc = context.read<LanguageBloc>();
    final currentTheme = Theme.of(context).brightness == Brightness.dark 
        ? ThemeMode.dark 
        : ThemeMode.light;
    final currentLocale = languageBloc.state.locale;
    
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          width: 140,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProgressStepCompact(0, '1'),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: _currentStep >= 1
                      ? AppTheme.primaryColor
                      : Colors.grey[300],
                ),
              ),
              _buildProgressStepCompact(1, '2'),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: _currentStep >= 2
                      ? AppTheme.primaryColor
                      : Colors.grey[300],
                ),
              ),
              _buildProgressStepCompact(2, '3'),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              currentLocale.languageCode == 'ar'
                  ? Icons.translate
                  : Icons.language,
              color: Theme.of(context).iconTheme.color,
            ),
            tooltip: currentLocale.languageCode == 'ar'
                ? (localizations?.translate('switchToEnglish') ?? 'Switch to English')
                : (localizations?.translate('switchToArabic') ?? 'Switch to Arabic'),
            onPressed: () {
              final newLocale = currentLocale.languageCode == 'ar'
                  ? const Locale('en')
                  : const Locale('ar');
              languageBloc.add(ChangeLanguage(newLocale));
            },
          ),
          IconButton(
            icon: Icon(
              currentTheme == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Theme.of(context).iconTheme.color,
            ),
            tooltip: currentTheme == ThemeMode.dark
                ? (localizations?.translate('switchToLightMode') ?? 'Switch to Light Mode')
                : (localizations?.translate('switchToDarkMode') ?? 'Switch to Dark Mode'),
            onPressed: () {
              themeBloc.add(const ToggleTheme());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo or App Name
                  Text(
                    localizations?.translate('register') ?? 'Register',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations?.translate('createCompanyAccount') ??
                        'Create your company account',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Error message
                      if (_generalError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _generalError!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      
                      // Step content
                      if (_currentStep == 0) _buildCompanyStep(),
                      if (_currentStep == 1) _buildOwnerStep(),
                      if (_currentStep == 2) _buildPlanStep(),
                      
                      const SizedBox(height: 24),
                      
                      // Navigation buttons
                      Row(
                        children: [
                          if (_currentStep > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : () {
                                  setState(() {
                                    _currentStep--;
                                    _errors = {};
                                    _generalError = null;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  localizations?.translate('back') ?? 'Back',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          if (_currentStep > 0) const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_isLoading || _stepCheckLoading) ? null : 
                                  (_currentStep < 2 ? _handleNext : _handleRegister),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: (_isLoading || _stepCheckLoading)
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _currentStep < 2
                                          ? (localizations?.translate('next') ?? 'Next')
                                          : (localizations?.translate('register') ?? 'Register'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            localizations?.translate('alreadyHaveAccount') ?? 
                                'Already have an account?',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              localizations?.translate('signIn') ?? 'Sign In',
                              style: TextStyle(color: AppTheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildProgressStepCompact(int step, String label) {
    final isActive = _currentStep >= step;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildCompanyStep() {
    final localizations = AppLocalizations.of(context);
    final isRTL = localizations?.isRTL ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations?.translate('companyInformation') ?? 'Company Information',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        
        // Company Name
        TextFormField(
          controller: _companyNameController,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('companyName') ?? 'Company Name'} *',
            prefixIcon: const Icon(Icons.business),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _errors['companyName'],
          ),
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          validator: _validateCompanyName,
          onChanged: (_) {
            setState(() {
              _errors.remove('companyName');
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Company Domain
        TextFormField(
          controller: _companyDomainController,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('companyDomain') ?? 'Company Domain'} *',
            prefixIcon: const Icon(Icons.domain),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            hintText: 'e.g., example.com',
            errorText: _errors['companyDomain'],
            helperText: localizations?.translate('domainHint') ?? 
                'This will be used as your company identifier',
          ),
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          validator: _validateCompanyDomain,
          onChanged: (_) {
            setState(() {
              _errors.remove('companyDomain');
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Specialization
        DropdownButtonFormField<String>(
          initialValue: _specialization,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('specialization') ?? 'Specialization'} *',
            prefixIcon: const Icon(Icons.category),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            DropdownMenuItem(
              value: 'real_estate',
              child: Text(localizations?.translate('realEstate') ?? 'Real Estate'),
            ),
            DropdownMenuItem(
              value: 'services',
              child: Text(localizations?.translate('services') ?? 'Services'),
            ),
            DropdownMenuItem(
              value: 'products',
              child: Text(localizations?.translate('products') ?? 'Products'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _specialization = value;
              });
            }
          },
        ),
      ],
    );
  }
  
  Widget _buildOwnerStep() {
    final localizations = AppLocalizations.of(context);
    final isRTL = localizations?.isRTL ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations?.translate('ownerInformation') ?? 'Owner Information',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        
        // First Name (full width so label is not cut off)
        TextFormField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('firstName') ?? 'First Name'} *',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _errors['firstName'],
          ),
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          validator: _validateFirstName,
          onChanged: (_) {
            setState(() {
              _errors.remove('firstName');
            });
          },
        ),
        const SizedBox(height: 16),
        // Last Name (full width so label is not cut off)
        TextFormField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('lastName') ?? 'Last Name'} *',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _errors['lastName'],
          ),
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          validator: _validateLastName,
          onChanged: (_) {
            setState(() {
              _errors.remove('lastName');
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('email') ?? 'Email'} *',
            prefixIcon: const Icon(Icons.email),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _errors['email'],
          ),
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          validator: _validateEmail,
          onChanged: (_) {
            setState(() {
              _errors.remove('email');
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Username
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('username') ?? 'Username'} *',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _errors['username'],
          ),
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          validator: _validateUsername,
          onChanged: (_) {
            setState(() {
              _errors.remove('username');
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Phone
        PhoneInput(
          value: _phoneController.text,
          onChanged: (value) {
            _phoneController.text = value;
            setState(() {
              _errors.remove('phone');
            });
          },
          hintText: localizations?.translate('enterPhone') ?? 'Enter phone number',
          error: _errors.containsKey('phone'),
          defaultCountry: 'SY',
        ),
        if (_errors.containsKey('phone'))
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              _errors['phone']!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        
        // Password
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('password') ?? 'Password'} *',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _errors['password'],
            helperText: localizations?.translate('passwordRequirements') ?? 
                'Password must be at least 8 characters',
          ),
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          validator: _validatePassword,
          onChanged: (_) {
            setState(() {
              _errors.remove('password');
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: '${localizations?.translate('confirmPassword') ?? 'Confirm Password'} *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _errors['confirmPassword'],
          ),
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          validator: _validateConfirmPassword,
          onChanged: (_) {
            setState(() {
              _errors.remove('confirmPassword');
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildPlanStep() {
    final localizations = AppLocalizations.of(context);
    final languageBloc = context.read<LanguageBloc>();
    final language = languageBloc.state.locale.languageCode;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations?.translate('selectPlan') ?? 'Select a Plan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          localizations?.translate('planSelectionHint') ?? 
              'Choose the plan that fits your team. You can switch later and no payment details are required now.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        
        // Billing Cycle Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizations?.translate('billingCycle') ?? 'Billing cycle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBillingCycleButton(
                    'monthly',
                    localizations?.translate('monthly') ?? 'Monthly',
                  ),
                  _buildBillingCycleButton(
                    'yearly',
                    localizations?.translate('yearly') ?? 'Yearly',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Plans List
        if (_plansLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_plansError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Text(
              _plansError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          )
        else if (_plans.isEmpty)
          Text(
            localizations?.translate('noPlansAvailable') ?? 
                'No paid plans are published yet. You can continue with the free trial.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          )
        else
          ..._plans.map((plan) => _buildPlanCard(plan, language)),
        
        const SizedBox(height: 16),
        
        Text(
          localizations?.translate('planNoteNoPayment') ?? 
              'We activate your chosen plan immediately—upgrade or downgrade anytime from settings.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildBillingCycleButton(String cycle, String label) {
    final isSelected = _billingCycle == cycle;
    return GestureDetector(
      onTap: () {
        setState(() {
          _billingCycle = cycle;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlanCard(PlanModel plan, String language) {
    final localizations = AppLocalizations.of(context);
    final isSelected = _selectedPlan?.id == plan.id;
    final price = plan.getPrice(_billingCycle);
    final priceText = price > 0
        ? '\$${price.toStringAsFixed(2)}'
        : (localizations?.translate('free') ?? 'Free');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected 
            ? AppTheme.primaryColor.withValues(alpha: 0.1) 
            : Colors.transparent,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPlan = plan;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.getDisplayName(language),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.getDisplayDescription(language),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        priceText,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _billingCycle == 'monthly'
                            ? (localizations?.translate('perMonth') ?? 'per month')
                            : (localizations?.translate('perYear') ?? 'per year'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${localizations?.translate('usersIncluded') ?? 'Users'}: ${plan.users}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${localizations?.translate('clientsIncluded') ?? 'Clients'}: ${plan.clients}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${localizations?.translate('storageIncluded') ?? 'Storage'}: ${plan.storage} GB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (plan.trialDays > 0)
                    Expanded(
                      child: Text(
                        '${plan.trialDays} ${localizations?.translate('trialDaysLabel') ?? 'trial days'}',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
