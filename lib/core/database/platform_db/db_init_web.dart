import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

bool _databaseInitialized = false;

void initPlatformDatabase() {
  if (kIsWeb && !_databaseInitialized) {
    databaseFactory = databaseFactoryFfiWeb;
    _databaseInitialized = true;
  }
}
