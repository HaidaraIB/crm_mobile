import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_error_helper.dart';
import '../../core/utils/device_location.dart';
import '../../core/utils/field_visit_api_errors.dart';
import '../location_issue_dialog.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/api_service.dart';
import '../../utils/compress_image_for_chat.dart';
import '../media/open_app_media_viewer.dart';

const _maxPhotoBytes = 5 * 1024 * 1024;
const _allowedExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};

class AddFieldVisitModal extends StatefulWidget {
  final int leadId;
  final String leadName;
  final VoidCallback? onSave;

  const AddFieldVisitModal({
    super.key,
    required this.leadId,
    required this.leadName,
    this.onSave,
  });

  @override
  State<AddFieldVisitModal> createState() => _AddFieldVisitModalState();
}

class _AddFieldVisitModalState extends State<AddFieldVisitModal> {
  final ApiService _apiService = ApiService();
  final TextEditingController _summaryController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _visitDatetime;
  DateTime? _upcomingVisitDate;
  String? _photoPath;
  bool _isSaving = false;
  bool _isLocating = false;
  String? _generalError;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _visitDatetime = DateTime.now();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  String _t(String key, String fallback) {
    return AppLocalizations.of(context)?.translate(key) ?? fallback;
  }

  String _localizedKey(String key, String fallback) {
    final translated = AppLocalizations.of(context)?.translate(key);
    if (translated != null && translated != key) return translated;
    return fallback;
  }

  void _applyFieldVisitError(FieldVisitCreateException error) {
    final fieldErrors = <String, String>{};
    error.fieldMessageKeys.forEach((field, key) {
      fieldErrors[field] = _localizedKey(key, key);
    });

    String? banner;
    if (error.generalMessageKey != null) {
      banner = _localizedKey(
        error.generalMessageKey!,
        error.generalMessageKey!,
      );
    } else if (fieldErrors.isEmpty) {
      banner = _localizedKey('failedToAddFieldVisit', 'Failed to save field visit');
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(fieldErrors);
      _generalError = banner;
    });
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() => _errors.remove(field));
    }
  }

  String? _validatePhotoFile(String path) {
    final lower = path.toLowerCase();
    final ext = lower.contains('.') ? '.${lower.split('.').last}' : '';
    if (!_allowedExtensions.contains(ext)) {
      return _t('clientLocationPhotoInvalidType', 'Invalid image type');
    }
    final file = File(path);
    if (!file.existsSync()) return _t('clientLocationPhotoInvalidType', 'Invalid image');
    if (file.lengthSync() > _maxPhotoBytes) {
      return _t('clientLocationPhotoTooLarge', 'Image too large');
    }
    return null;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      var path = picked.path;
      final file = File(path);
      if (file.lengthSync() > _maxPhotoBytes) {
        path = await compressImageForChatIfNeeded(path);
      }

      final photoError = _validatePhotoFile(path);
      if (photoError != null) {
        setState(() => _errors['clientLocationPhoto'] = photoError);
        return;
      }

      setState(() {
        _photoPath = path;
        _errors.remove('clientLocationPhoto');
      });
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, e.toString());
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _errors.remove('clientLocationPhoto');
    });
  }

  Future<void> _selectVisitDatetime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDatetime ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (!mounted) return;
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _visitDatetime != null
            ? TimeOfDay.fromDateTime(_visitDatetime!)
            : TimeOfDay.now(),
      );
      if (!mounted) return;
      if (time != null) {
        setState(() {
          _visitDatetime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          _clearError('visitDatetime');
        });
      }
    }
  }

  void _setVisitDatetimeToNow() {
    setState(() {
      _visitDatetime = DateTime.now();
      _clearError('visitDatetime');
    });
  }

  Future<void> _selectUpcomingVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _upcomingVisitDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (!mounted) return;
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _upcomingVisitDate != null
            ? TimeOfDay.fromDateTime(_upcomingVisitDate!)
            : TimeOfDay.now(),
      );
      if (!mounted) return;
      if (time != null) {
        setState(() {
          _upcomingVisitDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<({double latitude, double longitude, double accuracy})?>
      _getCurrentPosition() async {
    try {
      final position = await getAccurateDevicePosition();
      return (
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } on DeviceLocationException catch (e) {
      if (mounted) {
        await showDeviceLocationIssueDialog(context, e.failure);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _validateForm() {
    final newErrors = <String, String>{};
    if (_summaryController.text.trim().isEmpty) {
      newErrors['summary'] =
          _t('visitSummaryRequired', 'Summary is required');
    }
    if (_visitDatetime == null) {
      newErrors['visitDatetime'] =
          _t('visitDatetimeRequired', 'Visit date and time is required');
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(newErrors);
      _generalError = null;
    });
    return newErrors.isEmpty;
  }

  Future<void> _save() async {
    if (!_validateForm()) return;

    setState(() {
      _isSaving = true;
      _isLocating = true;
      _generalError = null;
    });

    try {
      final position = await _getCurrentPosition();
      if (position == null) {
        if (_generalError == null) {
          setState(() {
            _generalError = _t(
              'employeeLocationRequired',
              'Could not get location',
            );
          });
        }
        return;
      }

      if (!mounted) return;
      setState(() => _isLocating = false);

      await _apiService.createClientFieldVisit(
        leadId: widget.leadId,
        summary: _summaryController.text.trim(),
        visitDatetime: _visitDatetime!,
        employeeLatitude: position.latitude,
        employeeLongitude: position.longitude,
        employeeLocationAccuracy: position.accuracy,
        upcomingVisitDate: _upcomingVisitDate,
        clientLocationPhotoPath: _photoPath,
      );

      if (!mounted) return;
      Navigator.pop(context);
      SnackbarHelper.showSuccess(
        context,
        _t('fieldVisitCreatedSuccessfully', 'Field visit saved'),
      );
      widget.onSave?.call();
    } catch (e) {
      if (!mounted) return;
      if (e is FieldVisitCreateException) {
        _applyFieldVisitError(e);
      } else {
        setState(() {
          _errors.clear();
          _generalError = ApiErrorHelper.toUserMessage(
            context,
            e,
            fallback: _localizedKey(
              'failedToAddFieldVisit',
              'Failed to save field visit',
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isLocating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = _isSaving || _isLocating;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${localizations?.translate('addFieldVisit') ?? 'Add field visit'} '
                      '${localizations?.translate('for') ?? 'for'} ${widget.leadName}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: busy ? null : () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_generalError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _generalError!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      localizations?.translate('visitSummary') ?? 'Summary',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _summaryController,
                      maxLines: 4,
                      enabled: !busy,
                      onChanged: (_) => _clearError('summary'),
                      decoration: InputDecoration(
                        hintText: localizations?.translate('visitSummaryHint') ??
                            'Describe the visit…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: _errors['summary'],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      localizations?.translate('visitDatetime') ??
                          'Visit date & time',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : _selectVisitDatetime,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _visitDatetime != null
                                  ? _visitDatetime!.toString().substring(0, 16)
                                  : localizations?.translate('visitDatetime') ??
                                      'Select date & time',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: busy ? null : _setVisitDatetimeToNow,
                          icon: const Icon(Icons.access_time),
                          label: Text(localizations?.translate('now') ?? 'Now'),
                        ),
                      ],
                    ),
                    if (_errors['visitDatetime'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _errors['visitDatetime']!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      localizations?.translate('upcomingVisitDate') ??
                          'Next visit (optional)',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : _selectUpcomingVisitDate,
                        icon: const Icon(Icons.event_available),
                        label: Text(
                          _upcomingVisitDate != null
                              ? _upcomingVisitDate!.toString().substring(0, 16)
                              : localizations?.translate('selectUpcomingVisitDate') ??
                                  'Select upcoming visit date',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      localizations?.translate('clientLocationPhoto') ??
                          'Client location photo',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations?.translate('clientLocationPhotoHint') ??
                          'Optional — photo of the client location',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => _pickPhoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            localizations?.translate('takeClientLocationPhoto') ??
                                'Take photo',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => _pickPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            localizations?.translate('uploadClientLocationPhoto') ??
                                'Upload photo',
                          ),
                        ),
                        if (_photoPath != null)
                          OutlinedButton.icon(
                            onPressed: busy ? null : _removePhoto,
                            icon: const Icon(Icons.delete_outline),
                            label: Text(
                              localizations?.translate('removeClientLocationPhoto') ??
                                  'Remove photo',
                            ),
                          ),
                      ],
                    ),
                    if (_errors['clientLocationPhoto'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _errors['clientLocationPhoto']!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (_photoPath != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => openAppImageViewer(
                          context,
                          imageFilePath: _photoPath,
                          suggestedFilename: 'field_visit_location.jpg',
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_photoPath!),
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : () => Navigator.pop(context),
                            child: Text(localizations?.translate('cancel') ?? 'Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: busy ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: busy
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white.withValues(
                                          alpha: _isLocating ? 1 : 0.7,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isLocating
                                        ? (localizations?.translate('gettingLocation') ??
                                            'Getting location…')
                                        : (localizations?.translate('submit') ??
                                            'Submit'),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
