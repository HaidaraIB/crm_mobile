import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';

class AddCallModal extends StatefulWidget {
  final int leadId;
  final Function(int callMethodId, String notes, DateTime? followUpDate)? onSave;
  
  const AddCallModal({
    super.key,
    required this.leadId,
    this.onSave,
  });

  @override
  State<AddCallModal> createState() => _AddCallModalState();
}

class _AddCallModalState extends State<AddCallModal> {
  final ApiService _apiService = ApiService();
  int? _selectedCallMethodId;
  final TextEditingController _notesController = TextEditingController();
  DateTime? _followUpDate;
  List<CallMethodModel> _callMethods = [];
  bool _isLoadingCallMethods = true;
  String? _callMethodsError;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _loadCallMethods();
  }
  
  Future<void> _loadCallMethods() async {
    try {
      setState(() {
        _isLoadingCallMethods = true;
        _callMethodsError = null;
      });
      
      final callMethods = await _apiService.getCallMethods();
      
      setState(() {
        _callMethods = callMethods;
        _isLoadingCallMethods = false;
      });
    } catch (e) {
      setState(() {
        _callMethodsError = e.toString();
        _isLoadingCallMethods = false;
      });
    }
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _selectFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (!mounted) return;
    
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (!mounted) return;
      
      if (time != null) {
        setState(() {
          _followUpDate = DateTime(
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
  
  Future<void> _save() async {
    final localizations = AppLocalizations.of(context);
    if (_selectedCallMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.translate('pleaseSelectCallMethod') ?? 'Please select a call method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.translate('pleaseEnterNotes') ?? 'Please enter notes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_followUpDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.translate('followUpDateRequired') ?? 'Follow up date is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      await _apiService.addCallToLead(
        leadId: widget.leadId,
        callMethod: _selectedCallMethodId!,
        notes: _notesController.text.trim(),
        followUpDate: _followUpDate,
      );
      
      if (!mounted) return;
      
      // Close dialog first
      Navigator.pop(context);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.translate('callAdded') ?? 'Call added successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      // Call onSave callback for refresh
      widget.onSave?.call(
        _selectedCallMethodId!,
        _notesController.text.trim(),
        _followUpDate,
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizations?.translate('failedToAddCall') ?? 'Failed to add call'}: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations?.translate('addCall') ?? 'Add Call',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Call Method Dropdown
                    Text(
                      localizations?.translate('callMethod') ?? 'Call Method',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _isLoadingCallMethods
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ))
                        : _callMethodsError != null
                            ? Column(
                                children: [
                                  Text(
                                    'Failed to load call methods: $_callMethodsError',
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _loadCallMethods,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              )
                            : _callMethods.isEmpty
                                ? Text(
                                    localizations?.translate('noCallMethodsFound') ?? 'No call methods found',
                                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                                  )
                                : DropdownButtonFormField<int>(
                                    initialValue: _selectedCallMethodId,
                                    decoration: InputDecoration(
                                      hintText: localizations?.translate('selectItem') ?? 'Select item',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      suffixIcon: const Icon(Icons.arrow_drop_down),
                                    ),
                                    items: _callMethods.map((callMethod) {
                                      return DropdownMenuItem<int>(
                                        value: callMethod.id,
                                        child: Text(callMethod.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCallMethodId = value;
                                      });
                                    },
                                  ),
                    const SizedBox(height: 24),
                    
                    // Notes
                    Text(
                      localizations?.translate('notes') ?? 'Notes',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: localizations?.translate('notes') ?? 'Notes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Follow Up Date
                    Row(
                      children: [
                        Text(
                          localizations?.translate('followUpDate') ?? 'Follow Up Date',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _selectFollowUpDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _followUpDate != null
                              ? _followUpDate!.toString().substring(0, 16)
                              : localizations?.translate('selectFollowUpDate') ?? 'Select Follow Up Date',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                    // Note: Follow up date is now required, so we don't show remove button
                    const SizedBox(height: 24),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.6),
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
                                localizations?.translate('save') ?? 'Save',
                              ),
                      ),
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
