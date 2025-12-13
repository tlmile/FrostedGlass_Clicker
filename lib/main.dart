import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/task_entity.dart';
import 'start_page.dart';
import 'update_checker.dart'; // 导入 UpdateChecker 类

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive
    ..registerAdapter(TaskEntityAdapter())
    ..registerAdapter(StepEntityAdapter());

  await Hive.openBox<TaskEntity>('tasks');
  await Hive.openBox<StepEntity>('steps');

  final updateChecker = UpdateChecker();

  runApp(const AutoClickApp());

  // 在第一帧绘制完成后检查更新，确保有上下文可用
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      updateChecker.checkForUpdate(context: context);
    } else {
      updateChecker.checkForUpdate();
    }
  });
}

class AutoClickApp extends StatelessWidget {
  const AutoClickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoClick',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B86E5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050816),
        fontFamily: 'SF Pro', // 没有这个字体也没关系，会自动退回系统默认
      ),
      home: const StartPage(),
    );
  }
}
