import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app.dart';
import 'services/database_service.dart';
import 'controllers/task_controller.dart';
import 'controllers/ai_suggestion_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化服务
  await initServices();
  
  runApp(const MyApp());
}

Future<void> initServices() async {
  // 首先初始化数据库服务
  Get.put(DatabaseService(), permanent: true);
  await Get.find<DatabaseService>().onInit();
  
  // 初始化AI建议控制器
  Get.put(AiSuggestionController(), permanent: true);
  
  // 然后初始化依赖数据库的控制器
  Get.put(TaskController(), permanent: true);
}
