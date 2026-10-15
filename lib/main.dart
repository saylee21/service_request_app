import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'di/injector.dart';
import 'features/requests/domain/repositories/sync_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.hasBaseUrl) {
    await configureDependencies();
    // Recover any request stuck mid-sync from a previous session and start
    // draining the outbox.
    await getIt<SyncRepository>().onStartup();
  }

  runApp(const ServiceRequestApp());
}
