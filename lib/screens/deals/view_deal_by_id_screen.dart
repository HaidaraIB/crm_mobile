import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/api_error_helper.dart';
import '../../models/deal_model.dart';
import '../../services/api_service.dart';
import 'view_deal_screen.dart';

/// Loads a deal by id then shows [ViewDealScreen] (for deep links / named routes).
class ViewDealByIdScreen extends StatefulWidget {
  final int dealId;

  const ViewDealByIdScreen({super.key, required this.dealId});

  @override
  State<ViewDealByIdScreen> createState() => _ViewDealByIdScreenState();
}

class _ViewDealByIdScreenState extends State<ViewDealByIdScreen> {
  final ApiService _api = ApiService();
  DealModel? _deal;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final deal = await _api.getDeal(widget.dealId);
      if (!mounted) return;
      setState(() {
        _deal = deal;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deal = null;
        _error = ApiErrorHelper.toUserMessage(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_deal != null) {
      return ViewDealScreen(deal: _deal!);
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.translate('deals') ?? 'Deals'),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
