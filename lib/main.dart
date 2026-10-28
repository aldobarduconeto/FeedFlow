import 'package:feedflow/src/app.dart';
import 'package:flutter/material.dart';
import 'src/services/appearance_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppearanceService.instance.initialize();
  runApp(App());
}
