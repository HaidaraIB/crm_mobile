import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';

class LeadDetailsScreen extends StatefulWidget {
  final int leadId;
  
  const LeadDetailsScreen({super.key, required this.leadId});

  @override
  State<LeadDetailsScreen> createState() => _LeadDetailsScreenState();
}

class _LeadDetailsScreenState extends State<LeadDetailsScreen> {
  int _selectedTab = 0; // 0 = History, 1 = Deals
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.note, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(localizations?.translate('notes') ?? 'Notes'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search/Notes Input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: localizations?.translate('notes') ?? 'Notes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          // Tabs
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedTab == 0
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      localizations?.translate('history') ?? 'History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedTab == 0
                            ? AppTheme.primaryColor
                            : Colors.grey[600],
                        fontWeight: _selectedTab == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedTab == 1
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      localizations?.translate('deals') ?? 'Deals',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedTab == 1
                            ? AppTheme.primaryColor
                            : Colors.grey[600],
                        fontWeight: _selectedTab == 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Content
          Expanded(
            child: _selectedTab == 0
                ? _buildHistoryTab(context, localizations)
                : _buildDealsTab(context, localizations),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHistoryTab(BuildContext context, AppLocalizations? localizations) {
    final theme = Theme.of(context);
    
    // Mock data - replace with actual API call
    final activities = [
      {
        'title': localizations?.translate('noAnswer') ?? 'No answer',
        'date': '04/14/2025 11:42 PM',
        'user': 'admin',
        'reminder': '04/14/2025 09:41 PM',
        'status': 'pending',
      },
      {
        'title': localizations?.translate('meeting') ?? 'Meeting',
        'date': '04/14/2025 01:10 PM',
        'user': 'admin',
        'reminder': '04/14/2025 01:12 PM',
        'status': 'completed',
      },
    ];
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        final isPending = activity['status'] == 'pending';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activity['title'] as String,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.yellow.withValues(alpha: 0.2)
                            : Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPending
                            ? (localizations?.translate('pending') ?? 'Pending')
                            : (localizations?.translate('completed') ?? 'Completed'),
                        style: TextStyle(
                          color: isPending ? Colors.orange : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activity['date'] as String,
                  style: theme.textTheme.bodyMedium,
                ),
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      activity['user'] as String,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${localizations?.translate('reminder') ?? 'Reminder'}: ${activity['reminder']}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDealsTab(BuildContext context, AppLocalizations? localizations) {
    return Center(
      child: Text(
        localizations?.translate('noDealsFound') ?? 'No deals found',
      ),
    );
}
}

