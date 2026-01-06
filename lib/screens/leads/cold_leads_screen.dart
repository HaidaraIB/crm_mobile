import 'package:flutter/material.dart';
import 'all_leads_screen.dart';

class ColdLeadsScreen extends StatelessWidget {
  const ColdLeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AllLeadsScreen(
      type: 'cold',
      showAppBar: true,
    );
  }
}

