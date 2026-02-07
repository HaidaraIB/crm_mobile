import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/bloc/language/language_bloc.dart';
import '../../services/api_service.dart';
import '../../models/plan_model.dart';

/// شاشة لاختيار الخطة ودورة الفوترة (شهري/سنوي).
/// تُستخدم من شاشة الدفع لتغيير الخطة قبل فتح صفحة الدفع.
class SubscriptionPlanBillingPickerScreen extends StatefulWidget {
  const SubscriptionPlanBillingPickerScreen({
    super.key,
    this.initialPlanId,
    this.initialBillingCycle = 'monthly',
  });

  final int? initialPlanId;
  final String initialBillingCycle;

  @override
  State<SubscriptionPlanBillingPickerScreen> createState() =>
      _SubscriptionPlanBillingPickerScreenState();
}

class _SubscriptionPlanBillingPickerScreenState
    extends State<SubscriptionPlanBillingPickerScreen> {
  List<PlanModel> _plans = [];
  PlanModel? _selectedPlan;
  String _billingCycle = 'monthly';
  bool _plansLoading = true;
  String? _plansError;

  @override
  void initState() {
    super.initState();
    _billingCycle = widget.initialBillingCycle;
    _loadPlans();
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
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _plansLoading = false;
        if (plans.isNotEmpty) {
          final match = plans.where((p) => p.id == widget.initialPlanId);
          _selectedPlan = match.isEmpty ? plans.first : match.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plansError = e.toString().replaceAll('Exception: ', '');
        _plansLoading = false;
      });
    }
  }

  Widget _buildBillingCycleButton(String cycle, String label) {
    final isSelected = _billingCycle == cycle;
    return GestureDetector(
      onTap: () => setState(() => _billingCycle = cycle),
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
        onTap: () => setState(() => _selectedPlan = plan),
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

  void _confirm() {
    if (_selectedPlan == null) return;
    Navigator.of(context).pop(<String, dynamic>{
      'planId': _selectedPlan!.id,
      'billingCycle': _billingCycle,
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageBloc = context.watch<LanguageBloc>();
    final locale = languageBloc.state.locale;
    final language = locale.languageCode;
    final l10n = AppLocalizations(locale);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(locale.languageCode == 'ar' ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.translate('changePlanOrBilling')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                l10n.translate('planSelectionHint'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.translate('billingCycle'),
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
                          l10n.translate('monthly'),
                        ),
                        _buildBillingCycleButton(
                          'yearly',
                          l10n.translate('yearly'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_plansLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_plansError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _plansError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_plans.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.translate('noPlansAvailable'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._plans.map((plan) => _buildPlanCard(plan, language)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _selectedPlan == null ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(l10n.translate('confirmPlanSelection')),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
