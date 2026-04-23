import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/objectbox_service.dart';
import 'services/sr_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  final themeProvider = await ThemeProvider.create();
  final navigatorKey = GlobalKey<NavigatorState>();
  final obxService = await ObjectBoxService.create();
  final srService = SRService(obxService, prefs);
  await NotificationService.instance.initialize(navigatorKey);
  runApp(
    MyApp(
      storage: storage,
      themeProvider: themeProvider,
      navigatorKey: navigatorKey,
      srService: srService,
    ),
  );
}
