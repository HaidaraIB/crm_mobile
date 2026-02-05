import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/phone_input.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  File? _selectedImage;
  String? _profilePhotoUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ApiService();
      final user = await apiService.getCurrentUser();
      
      setState(() {
        _currentUser = user;
        _firstNameController.text = user.firstName ?? '';
        _lastNameController.text = user.lastName ?? '';
        _phoneController.text = user.phone;
        _emailController.text = user.email ?? '';
        _profilePhotoUrl = user.profilePhoto ?? user.avatar;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false, // Improve performance
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations?.translate('errorPickingImage') ?? 'Error picking image'}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      String errorMessage = e.toString();
      
      // Handle specific camera errors
      if (errorMessage.contains('camera') || errorMessage.contains('Camera')) {
        errorMessage = localizations?.translate('cameraNotAvailable') ?? 
                       'Camera is not available or access was denied. Please check your device settings.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations?.translate('errorTakingPhoto') ?? 'Error taking photo'}: $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showImageSourceDialog() async {
    final localizations = AppLocalizations.of(context);
    final isIPad = Theme.of(context).platform == TargetPlatform.iOS && 
                   MediaQuery.of(context).size.shortestSide >= 600;
    
    if (isIPad) {
      // Use Cupertino action sheet on iPad for better compatibility
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          return CupertinoActionSheet(
            title: Text(localizations?.translate('selectImageSource') ?? 'Select Image Source'),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library, color: CupertinoColors.activeBlue),
                    const SizedBox(width: 8),
                    Text(localizations?.translate('chooseFromGallery') ?? 'Choose from Gallery'),
                  ],
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, color: CupertinoColors.activeBlue),
                    const SizedBox(width: 8),
                    Text(localizations?.translate('takePhoto') ?? 'Take Photo'),
                  ],
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              isDestructiveAction: true,
              child: Text(localizations?.translate('cancel') ?? 'Cancel'),
            ),
          );
        },
      );
    } else {
      // Use bottom sheet on iPhone/Android
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(localizations?.translate('chooseFromGallery') ?? 'Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(localizations?.translate('takePhoto') ?? 'Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final apiService = ApiService();
      final updatedUser = await apiService.updateUser(
        userId: _currentUser!.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        profilePhotoPath: _selectedImage?.path,
      );

      // Update stored user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AppConstants.currentUserKey,
        jsonEncode(updatedUser.toJson()),
      );

      setState(() {
        _currentUser = updatedUser;
        _selectedImage = null;
        _profilePhotoUrl = updatedUser.profilePhoto ?? updatedUser.avatar;
        _isSaving = false;
        _successMessage = AppLocalizations.of(context)?.translate('profileUpdatedSuccessfully') ?? 'Profile updated successfully!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        // Pop the screen and return true to indicate profile was updated
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isRTL = localizations?.isRTL ?? false;
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations?.translate('profile') ?? 'Profile'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations?.translate('profile') ?? 'Profile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Failed to load profile',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserData,
                child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.translate('profile') ?? 'Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Photo Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                                  ? NetworkImage(_profilePhotoUrl!)
                                  : null,
                          child: _selectedImage == null && (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              onPressed: _showImageSourceDialog,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations?.translate('clickToChangePhoto') ?? 'Click to change photo',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              // First Name Field
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: localizations?.translate('firstName') ?? 'First Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations?.translate('firstNameRequired') ?? 'First name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Last Name Field
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: localizations?.translate('lastName') ?? 'Last Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations?.translate('lastNameRequired') ?? 'Last name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field (Read-only)
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: localizations?.translate('email') ?? 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                enabled: false,
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
              const SizedBox(height: 16),

              // Phone Field
              PhoneInput(
                value: _phoneController.text,
                onChanged: (value) {
                  setState(() {
                    _phoneController.text = value;
                  });
                },
                hintText: localizations?.translate('phone') ?? 'Phone',
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        localizations?.translate('saveProfile') ?? 'Save Profile',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

