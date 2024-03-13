import 'package:assignment/Constants/constant.dart';

class DataModel {
  int? id;
  String message_ = '';
  String timestamp = '';

  set messageSetter(String newMessge) {
    message_ = newMessge;
  }

  set timeForData(String dateTime) {
    timestamp = dateTime;
  }

  DataModel(this.message_, this.timestamp);

  DataModel.withId(
    this.id,
    this.message_,
    this.timestamp,
  );

  DataModel.fromJson(Map<String, dynamic> map) {
    id = map[colId];
    message_ = map[message];
    timeForData = map[time];
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = Map();

    if (id != null) {
      map['_colId'] = id;
    }
    map['_data'] = message_;
    map['_timeStamp'] = timestamp;

    return map;
  }
}
