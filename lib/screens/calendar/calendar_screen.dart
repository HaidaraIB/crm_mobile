import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../services/api_service.dart';
import '../leads/lead_profile_screen.dart';

class CalendarScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const CalendarScreen({super.key, this.initialDate});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ApiService _apiService = ApiService();
  late DateTime _selectedDate;
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadEvents();
  }
  
  void navigateMonth(int months) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + months,
      );
    });
  }
  
  void refreshEvents() {
    _loadEvents();
  }
  
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get all stages to map stage IDs to names
      final stages = await _apiService.getStages();
      final stageMap = <int, String>{};
      for (final stage in stages) {
        stageMap[stage.id] = stage.name;
      }
      
      // Get all leads to map lead IDs to names
      final leadsResponse = await _apiService.getLeads();
      final leads = leadsResponse['results'] as List<LeadModel>? ?? [];
      final leadMap = <int, LeadModel>{};
      for (final lead in leads) {
        leadMap[lead.id] = lead;
      }
      
      // Get all client tasks directly from API
      final tasks = await _apiService.getAllClientTasks();
      
      final events = <CalendarEvent>[];
      
      // Extract reminders from tasks
      final localizations = mounted ? AppLocalizations.of(context) : null;
      for (final task in tasks) {
        // Only add events for tasks with reminder dates and valid leads
        if (task.reminderDate != null && leadMap.containsKey(task.client)) {
          final lead = leadMap[task.client]!;
          final stageName = stageMap[task.stage] ?? (localizations?.translate('unknown') ?? 'Unknown');
          events.add(CalendarEvent(
            id: task.id,
            title: stageName,
            description: task.notes,
            date: task.reminderDate!,
            leadId: lead.id,
            leadName: lead.name,
            type: 'reminder',
          ));
        }
      }
      
      // Sort events by date
      events.sort((a, b) => a.date.compareTo(b.date));
      
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      debugPrint('Failed to load calendar events: $e');
    }
  }

  List<CalendarEvent> _getEventsForDate(DateTime date) {
    return _events.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final eventsForSelectedDate = _getEventsForDate(_selectedDate);
    
    return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEvents,
                        child: Text(localizations?.translate('tryAgain') ?? 'Try Again'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Calendar Grid
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Weekday headers
                              Row(
                                children: [
                                  localizations?.translate('sunday') ?? 'Sun',
                                  localizations?.translate('monday') ?? 'Mon',
                                  localizations?.translate('tuesday') ?? 'Tue',
                                  localizations?.translate('wednesday') ?? 'Wed',
                                  localizations?.translate('thursday') ?? 'Thu',
                                  localizations?.translate('friday') ?? 'Fri',
                                  localizations?.translate('saturday') ?? 'Sat',
                                ]
                                    .map((day) => Expanded(
                                          child: Center(
                                            child: Text(
                                              day,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 8),
                              
                              // Calendar days
                              _buildCalendarGrid(theme, isDark),
                              
                              const SizedBox(height: 24),
                              
                              // Events for selected date
                              if (eventsForSelectedDate.isNotEmpty) ...[
                                Text(
                                  DateFormat('EEEE, MMMM d', localizations?.locale.languageCode ?? 'en').format(_selectedDate),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...eventsForSelectedDate.map((event) => _buildEventCard(event, theme)),
                              ] else ...[
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.event_busy,
                                          size: 64,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          localizations?.translate('noEvents') ?? 'No events for this date',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
  }

  Widget _buildCalendarGrid(ThemeData theme, bool isDark) {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday, 6 = Saturday
    
    final daysInMonth = lastDayOfMonth.day;
    final weeks = <List<DateTime?>>[];
    List<DateTime?> currentWeek = [];
    
    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstDayWeekday; i++) {
      currentWeek.add(null);
    }
    
    // Add all days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      currentWeek.add(DateTime(_selectedDate.year, _selectedDate.month, day));
      
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }
    
    // Add remaining empty cells
    while (currentWeek.length < 7) {
      currentWeek.add(null);
    }
    if (currentWeek.isNotEmpty) {
      weeks.add(currentWeek);
    }
    
    return Column(
      children: weeks.map((week) {
        return Row(
          children: week.map((date) {
            if (date == null) {
              return Expanded(child: Container());
            }
            
            final isSelected = date.year == _selectedDate.year &&
                date.month == _selectedDate.month &&
                date.day == _selectedDate.day;
            final isToday = date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;
            final hasEvents = _getEventsForDate(date).isNotEmpty;
            
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : (isToday
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.transparent),
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(
                            color: AppTheme.primaryColor,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? Colors.white
                              : (isToday
                                  ? AppTheme.primaryColor
                                  : theme.colorScheme.onSurface),
                          fontWeight: isSelected || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (hasEvents)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildEventCard(CalendarEvent event, ThemeData theme) {
    final localizations = AppLocalizations.of(context);
    final timeFormat = DateFormat('h:mm a', localizations?.locale.languageCode ?? 'en');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.notifications,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          event.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  event.leadName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.description,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  timeFormat.format(event.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        onTap: () {
          // Navigate to lead profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeadProfileScreen(leadId: event.leadId),
            ),
          ).then((_) {
            // Refresh events when returning from lead profile
            _loadEvents();
          });
        },
      ),
    );
  }
}

class CalendarEvent {
  final int id;
  final String title; // Stage name (action type)
  final String description;
  final DateTime date;
  final int leadId;
  final String leadName;
  final String type;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.leadId,
    required this.leadName,
    required this.type,
  });
}

