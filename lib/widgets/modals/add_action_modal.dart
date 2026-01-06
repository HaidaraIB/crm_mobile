import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
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
  
  void _save() {
    if (_selectedStageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an action type')),
      );
      return;
    }
    
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter notes')),
      );
      return;
    }
    
    // Close modal first, then call onSave
    Navigator.pop(context);
    
    widget.onSave?.call(
      _selectedStageId!,
      _notesController.text.trim(),
      _reminderDate,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        return Material(
          color: theme.scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  localizations?.translate('addAction') ?? 'Add Action',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: keyboardHeight > 0 ? keyboardHeight + 8 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                    ],
                  ),
                ),
              ),
              
              // Save Button
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + keyboardHeight,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      localizations?.translate('save') ?? 'Save',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}


