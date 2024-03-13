import 'package:assignment/Constants/constant.dart';
import 'package:assignment/model/data.model.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DbInstance {
  static final DbInstance _instance = DbInstance._internal();
  factory DbInstance() => _instance;

  static Database? _dbInstance;

  Future<Database> get dbInstance async {
    if (_dbInstance == null) {
      _dbInstance = await _initDB();
    }
    return _dbInstance!;
  }

  DbInstance._internal();

  Future<Database> _initDB() async {
    var directory = await getApplicationDocumentsDirectory();
    String path = join(directory.path, DB_NAME);

    //clean slate
    await deleteDatabase(path);

    return await openDatabase(
      path,
      version: DB_VERSION,
      onCreate: (db, version) async {
        //creates table for replaySubject

        await db.execute(
            'CREATE TABLE $SECOND_TABLE($colId INTEGER PRIMARY KEY AUTOINCREMENT,$time TEXT,$message TEXT)');

        //creates table for behavior subject.
        await db.execute(
            'CREATE TABLE $TABLE_NAME($colId INTEGER PRIMARY KEY AUTOINCREMENT,$time TEXT,$message TEXT)');
      },
    );
  }
}
