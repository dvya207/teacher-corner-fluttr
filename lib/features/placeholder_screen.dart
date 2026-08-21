import 'package:flutter/material.dart';

import '../core/theme/app_typography.dart';
import '../core/widgets/tc_app_bar.dart';

/// Delete this file once every route has a real screen.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TcAppBar(title: title),
      body: Center(child: Text('$title — not built yet', style: AppTypography.bodyMedium)),
    );
  }
}
