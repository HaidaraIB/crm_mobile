import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lead_model.dart';

class CallSelectionModal extends StatelessWidget {
  final LeadModel lead;
  
  const CallSelectionModal({super.key, required this.lead});

  Future<void> _makeCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    // Get phone numbers
    final phoneNumbers = lead.phoneNumbers ?? [];
    
    final phonesToShow = phoneNumbers.isNotEmpty
        ? phoneNumbers
        : [PhoneNumber(
            id: 0,
            phoneNumber: lead.phone,
            phoneType: 'mobile',
            isPrimary: true,
          )];
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations?.translate('selectNumberToCall') ?? 'Select number to Call',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            ...phonesToShow.map((phone) {
              return ListTile(
                leading: Icon(
                  Icons.phone,
                  color: AppTheme.primaryColor,
                ),
                title: Text(phone.phoneNumber),
                subtitle: Text(phone.phoneType),
                trailing: phone.isPrimary
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Primary',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  _makeCall(phone.phoneNumber);
                  Navigator.pop(context);
                },
              );
            }),
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    localizations?.translate('cancel') ?? 'Cancel',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


