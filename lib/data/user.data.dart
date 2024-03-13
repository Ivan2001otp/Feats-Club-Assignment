class UserData {
  final String name;
  final String rollNo;

  UserData({
    required this.name,
    required this.rollNo,
  });

  //converts the data model to Json format
  //where data is store as key value pairs
  Map<String, String> toJson() {
    return {
      "Name": name,
      "rollNo": rollNo,
      "timeStamp": DateTime.now().millisecondsSinceEpoch.toString()
    };
  }
}
