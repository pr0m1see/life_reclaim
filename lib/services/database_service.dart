import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'database/database.dart';

class DatabaseService extends GetxService {
  static DatabaseService get to => Get.find<DatabaseService>();
  
  late AppDatabase _database;
  AppDatabase get database => _database;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    _database = AppDatabase();
    
    // 验证数据库连接
    try {
      await _database.customSelect('SELECT 1').get();
      debugPrint('✅ Database initialized successfully');
    } catch (e) {
      debugPrint('❌ Database initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> onClose() async {
    await _database.close();
    super.onClose();
  }
} 