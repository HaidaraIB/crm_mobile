import 'package:flutter/material.dart';
import 'all_leads_screen.dart';

class FreshLeadsScreen extends StatelessWidget {
  const FreshLeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AllLeadsScreen(
      type: 'fresh',
      showAppBar: true,
    );
  }
}

