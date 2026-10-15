import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'features/requests/presentation/screens/requests_screen.dart';
import 'features/setup/presentation/setup_screen.dart';
import 'theme/app_theme.dart';

class ServiceRequestApp extends StatelessWidget {
  const ServiceRequestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Service Requests',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: AppConfig.hasBaseUrl ? const RequestsScreen() : const SetupScreen(),
    );
  }
}
