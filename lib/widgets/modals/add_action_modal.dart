import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';

class AddActionModal extends StatefulWidget {
  final int leadId;
  final Function(int stageId, String notes, DateTime? reminderDate)? onSave;
  
  const AddActionModal({
    super.key,
    required this.leadId,
    this.onSave,
  });

  @override
  State<AddActionModal> createState() => _AddActionModalState();
}

class _AddActionModalState extends State<AddActionModal> {
  final ApiService _apiService = ApiService();
  int? _selectedStageId;
  final TextEditingController _notesController = TextEditingController();
  DateTime? _reminderDate;
  List<StageModel> _stages = [];
  bool _isLoadingStages = true;
  String? _stagesError;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _loadStages();
  }
  
  Future<void> _loadStages() async {
    try {
      setState(() {
        _isLoadingStages = true;
        _stagesError = null;
      });
      
      final stages = await _apiService.getStages();
      
      setState(() {
        _stages = stages;
        _isLoadingStages = false;
      });
    } catch (e) {
      setState(() {
        _stagesError = e.toString();
        _isLoadingStages = false;
      });
    }
  }
  
  String _getStageLocalizedName(String stageName, AppLocalizations? localizations) {
    // Try to match common stage names with localization keys
    final lowerName = stageName.toLowerCase();
    
    if (lowerName.contains('following') || lowerName.contains('follow')) {
      return localizations?.translate('following') ?? stageName;
    } else if (lowerName.contains('meeting')) {
      return localizations?.translate('meeting') ?? stageName;
    } else if (lowerName.contains('no answer') || lowerName.contains('noanswer')) {
      return localizations?.translate('noAnswer') ?? stageName;
    } else if (lowerName.contains('out of service') || lowerName.contains('outofservice')) {
      return localizations?.translate('outOfService') ?? stageName;
    } else if (lowerName.contains('cancel')) {
      return localizations?.translate('cancellation') ?? stageName;
    }
    
    // Return the original name if no match found
    return stageName;
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _selectReminderDate() async {
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
          _reminderDate = DateTime(
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
    if (_selectedStageId == null) {
      SnackbarHelper.showError(
        context,
        localizations?.translate('pleaseSelectActionType') ?? 'Please select an action type',
      );
      return;
    }
    
    if (_notesController.text.trim().isEmpty) {
      SnackbarHelper.showError(
        context,
        localizations?.translate('pleaseEnterNotes') ?? 'Please enter notes',
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      await _apiService.addActionToLead(
        leadId: widget.leadId,
        stage: _selectedStageId!,
        notes: _notesController.text.trim(),
        reminderDate: _reminderDate,
      );
      
      if (!mounted) return;
      
      // Close dialog first
      Navigator.pop(context);
      
      // Show success message
      SnackbarHelper.showSuccess(
        context,
        localizations?.translate('actionAdded') ?? 'Action added successfully',
      );
      
      // Call onSave callback for refresh
      widget.onSave?.call(
        _selectedStageId!,
        _notesController.text.trim(),
        _reminderDate,
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isSaving = false;
      });
      
      SnackbarHelper.showError(
        context,
        '${localizations?.translate('failedToAddAction') ?? 'Failed to add action'}: ${e.toString()}',
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
                    localizations?.translate('addAction') ?? 'Add Action',
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
                    // Action Type Dropdown
                    Text(
                      localizations?.translate('actionType') ?? 'Action type',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _isLoadingStages
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ))
                        : _stagesError != null
                            ? Column(
                                children: [
                                  Text(
                                    'Failed to load stages: $_stagesError',
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _loadStages,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              )
                            : _stages.isEmpty
                                ? Text(
                                    localizations?.translate('noStagesFound') ?? 'No stages found',
                                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                                  )
                                : DropdownButtonFormField<int>(
                                    initialValue: _selectedStageId,
                                    decoration: InputDecoration(
                                      hintText: localizations?.translate('selectItem') ?? 'Select item',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      suffixIcon: const Icon(Icons.arrow_drop_down),
                                    ),
                                    items: _stages.map((stage) {
                                      return DropdownMenuItem<int>(
                                        value: stage.id,
                                        child: Text(_getStageLocalizedName(stage.name, localizations)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedStageId = value;
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
                    
                    // Reminder Date
                    Text(
                      localizations?.translate('reminder') ?? 'Reminder',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _selectReminderDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _reminderDate != null
                              ? _reminderDate!.toString().substring(0, 16)
                              : localizations?.translate('selectReminder') ?? 'Select Reminder',
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
                    if (_reminderDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _reminderDate = null;
                            });
                          },
                          child: Text(
                            localizations?.translate('removeReminder') ?? 'Remove Reminder',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
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


