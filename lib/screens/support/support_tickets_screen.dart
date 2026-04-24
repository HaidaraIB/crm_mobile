import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_locales.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/support_ticket_model.dart';
import '../../services/api_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final ApiService _apiService = ApiService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<SupportTicket> _tickets = [];
  bool _isLoadingTickets = true;
  bool _isSubmitting = false;
  List<String> _screenshotPaths = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoadingTickets = true;
    });
    try {
      final data = await _apiService.getSupportTickets();
      if (mounted) {
        setState(() {
          _tickets =
              (data['results'] as List<dynamic>?)?.cast<SupportTicket>() ?? [];
          _isLoadingTickets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTickets = false;
        });
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(
                context,
              )?.translate('failedToLoadSupportTickets') ??
              'Failed to load support tickets',
        );
      }
    }
  }

  Future<void> _pickScreenshots() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final x in picked) {
        if (x.path.isNotEmpty) _screenshotPaths.add(x.path);
      }
    });
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) return;
    setState(() {
      _isSubmitting = true;
    });
    try {
      await _apiService.createSupportTicket(
        title,
        description,
        screenshotPaths: _screenshotPaths.isEmpty ? null : _screenshotPaths,
      );
      if (!mounted) return;
      SnackbarHelper.showSuccess(
        context,
        AppLocalizations.of(context)?.translate('ticketSubmittedSuccess') ??
            'Your request has been submitted successfully.',
      );
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _screenshotPaths = [];
        _isSubmitting = false;
      });
      _loadTickets();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(
                context,
              )?.translate('failedToCreateSupportTicket') ??
              'Failed to submit ticket. Please try again.',
        );
      }
    }
  }

  String _statusLabel(String status) {
    final t = AppLocalizations.of(context);
    switch (status) {
      case 'open':
        return t?.translate('statusOpen') ?? 'Open';
      case 'in_progress':
        return t?.translate('statusInProgress') ?? 'In Progress';
      case 'closed':
        return t?.translate('statusClosed') ?? 'Closed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isRTL = localizations?.isRTL ?? false;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            localizations?.translate('supportCenter') ?? 'Support Center',
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoadingTickets ? null : _loadTickets,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadTickets,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Submit a request
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            localizations?.translate('submitTicket') ??
                                'Submit a request',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText:
                                  localizations?.translate(
                                    'supportTicketTitle',
                                  ) ??
                                  'Subject',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return localizations?.translate(
                                      'subjectRequired',
                                    ) ??
                                    'Subject is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText:
                                  localizations?.translate(
                                    'supportTicketDescription',
                                  ) ??
                                  'Description',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 4,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return localizations?.translate(
                                      'descriptionRequired',
                                    ) ??
                                    'Description is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            localizations?.translate('screenshots') ??
                                'Screenshots (optional)',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: _pickScreenshots,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: Text(
                              localizations?.translate('addScreenshots') ??
                                  'Add screenshots',
                            ),
                          ),
                          if (_screenshotPaths.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _screenshotPaths.asMap().entries.map((
                                e,
                              ) {
                                return Chip(
                                  label: Text(
                                    'Image ${e.key + 1}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  onDeleted: () {
                                    setState(() {
                                      _screenshotPaths.removeAt(e.key);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitTicket,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    localizations?.translate('submit') ??
                                        'Submit',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Your tickets
                Text(
                  localizations?.translate('yourTickets') ?? 'Your tickets',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoadingTickets)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_tickets.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          localizations?.translate('noSupportTickets') ??
                              'No support tickets yet.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ticket = _tickets[index];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () => _showTicketDetail(ticket),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ticket.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          ticket.status,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _statusLabel(ticket.status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _statusColor(ticket.status),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (ticket.createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTicketDate(ticket.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ],
                                if (ticket.attachments.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.attach_file,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${ticket.attachments.length} ${localizations?.translate('attachments') ?? 'attachment(s)'}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTicketDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    final locale =
        AppLocalizations.of(context)?.locale ?? AppLocales.english;
    return DateFormat(
      'MMM d, yyyy · h:mm a',
      AppLocales.intlDateFormat(locale),
    ).format(date.toLocal());
  }

  /// Build full image URL for attachment (API may return relative path).
  String? _attachmentImageUrl(SupportTicketAttachment a) {
    String? raw = a.url ?? a.file;
    if (raw == null || raw.isEmpty) return null;
    raw = raw.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    String base = AppConstants.baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final origin = base.contains('/api') ? base.substring(0, base.indexOf('/api')) : base;
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$origin$path';
  }

  Widget _buildAttachmentPlaceholder(BuildContext context, int index) {
    return SizedBox(
      width: 120,
      height: 96,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              '${AppLocalizations.of(context)?.translate('screenshots') ?? 'Screenshot'} $index',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showTicketDetail(SupportTicket ticket) {
    final localizations = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ticket.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(ticket.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel(ticket.status),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _statusColor(ticket.status),
                  ),
                ),
              ),
              if (ticket.createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatTicketDate(ticket.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (ticket.updatedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${localizations?.translate('updatedAt') ?? 'Updated'}: ${_formatTicketDate(ticket.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                ticket.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (ticket.attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  localizations?.translate('screenshots') ?? 'Screenshots',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ticket.attachments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final a = entry.value;
                    final imageUrl = _attachmentImageUrl(a);
                    return InkWell(
                      onTap: () async {
                        if (imageUrl != null) {
                          final uri = Uri.tryParse(imageUrl);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 120,
                          height: 96,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  width: 120,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return SizedBox(
                                      width: 120,
                                      height: 96,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  (loadingProgress.expectedTotalBytes ?? 1)
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => _buildAttachmentPlaceholder(context, index + 1),
                                )
                              : _buildAttachmentPlaceholder(context, index + 1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
