import 'package:assignment/Constants/constant.dart';
import 'package:assignment/Database/db.instance.dart';
import 'package:assignment/model/data.model.dart';
import 'package:sqflite/sqflite.dart';

class UtilDB {
  Future<int> insertItem(DataModel dataModel) async {
    Database db = await DbInstance().dbInstance;

    var res = await db.insert(TABLE_NAME, dataModel.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore);

    return res;
  }

  Future<int> insertReplayItem(DataModel dataModel) async {
    Database db = await DbInstance().dbInstance;

    var res = await db.insert(SECOND_TABLE, dataModel.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore);

    return res;
  }

  Future<List<DataModel>> fetchReplayList(int offset_, int limit_) async {
    Database db = await DbInstance().dbInstance;

    if (!db.isOpen) {
      db = await DbInstance().dbInstance;
    }

    List<Map<String, dynamic>> res = await db.rawQuery(
        'SELECT * FROM $TABLE_NAME WHERE $colId BETWEEN ${offset_ + 1} AND $limit_');

    return List.generate(
      res.length,
      (index) => DataModel.fromJson(res[index]),
    );
  }

  //fetches the items of behavior subject.
  Future<List<DataModel>> fetchList(int offset_, int limit_) async {
    Database db = await DbInstance().dbInstance;
    if (!db.isOpen) {
      db = await DbInstance().dbInstance;
    }

    /*
      Note : The Sqlite do not supports offset .
     */

    List<Map<String, dynamic>> res = await db
        //.rawQuery('SELECT * FROM $TABLE_NAME LIMIT $limit_ OFFSET $offset_');
        .rawQuery(
            'SELECT * FROM $TABLE_NAME WHERE $colId BETWEEN ${offset_ + 1} AND $limit_');
    return List.generate(
      res.length,
      (index) => DataModel.fromJson(res[index]),
    );
  }

  void clearReplayDB() async {
    Database db = await DbInstance().dbInstance;
    db.execute('DELETE FROM $SECOND_TABLE');
    // db.execute('DROP TABLE $SECOND_TABLE');
  }

  void clearDatabase() async {
    Database db = await DbInstance().dbInstance;
    db.execute('DELETE FROM $TABLE_NAME');
    // db.execute('DROP TABLE $TABLE_NAME');

    db.close();
  }
}
