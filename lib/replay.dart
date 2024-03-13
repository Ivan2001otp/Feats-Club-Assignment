import 'dart:async';

import 'package:assignment/Database/db.instance.dart';
import 'package:assignment/Database/db_util.dart';
import 'package:assignment/data/system.data.dart';
import 'package:assignment/main.dart';
import 'package:assignment/model/data.model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:rxdart/rxdart.dart';

class ReplayWidget extends StatefulWidget {
  const ReplayWidget({super.key});

  @override
  State<ReplayWidget> createState() => _ReplayWidgetState();
}

class _ReplayWidgetState extends State<ReplayWidget> {
  List<Map<String, String>> l1 = List.empty(growable: true);

  UtilDB databaseInstance = UtilDB();

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  int noOfItems = 0; //this is 10 for every page
  int currPage = 1;
  int itemLimit = 10;

  int currOffsetVal = 0;
  int currLimitVal = 10;

  StreamController<Map<String, String>> r_userDataStreamController =
      StreamController<Map<String, String>>();

  late Stream<Map<String, String>> r_userDataStream;

  final replaySubjectItems =
      ReplaySubject<List<Map<String, String>>>(maxSize: 5);

  final systemDataGenerator_R =
      Stream.periodic(const Duration(seconds: 1), (_) {
    return {
      "timeStamp": DateTime.now().toIso8601String(),
      "message": 'SYS-DATA'
    };
  }).asBroadcastStream();

  final auto_user_data = Stream.periodic(const Duration(seconds: 2), (_) {
    return {
      "message": "This auto generated data",
      "timeStamp": "${DateTime.now()}"
    };
  });

  Map<String, String> initialData = {"Name": "No name", "Usn": "no usn"};

  @override
  void initState() {
    print('log - initstate exe');
    // TODO: implement initState

    //this below streams listens to the user input values
    r_userDataStream = r_userDataStreamController.stream.asBroadcastStream();

    //merge two streams .

    final sortedStreamItems =
        Rx.merge([r_userDataStream, systemDataGenerator_R])
            .distinctUnique()
            .bufferCount(2);

    sortedStreamItems.listen((event) {
      print(event[0]['timeStamp'].toString());
      var temp = event.toList();
      temp.sort(
        (a, b) {
          //convert string to int of timestamp value
          DateTime t1 = DateTime.parse(a['timeStamp']!);
          DateTime t2 = DateTime.parse(b['timeStamp']!);

          return t1.compareTo(t2);
        },
      );
    }).onData((data) {
      replaySubjectItems.add(data);
    });

    replaySubjectItems.listen((value) {
      value.forEach((element) async {
        String message_temp = element['message']!;

        String time_temp = element['timeStamp']!;

        DataModel dataModel = DataModel(message_temp, time_temp);
        int res = await databaseInstance.insertReplayItem(dataModel);
        print("inserted item in db - replay");

        if (currPage <= 10) {
          l1.add({"message": message_temp, "timeStamp": time_temp});
          currPage++;
        }
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    print("dispose executed!");

    _refreshController.dispose();

    replaySubjectItems
        .doOnCancel(() => print("log replaySubject releasing stopped.."))
        .listen(null);

    databaseInstance.clearReplayDB(); //clear the stuffs.

    r_userDataStreamController.close();
    r_userDataStream.listen(null);

    replaySubjectItems.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: Colors.deepPurple,
        centerTitle: false,
        title: Text(
          'ReplaySubject',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder(
        stream: replaySubjectItems.stream,
        builder: ((context, snapshot) {
          if (snapshot.hasData) {
            return SmartRefresher(
              onLoading: () async {
                if (currOffsetVal == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 4),
                      content: Text(
                        'No previous items!',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }

                if (currOffsetVal > 0) {
                  currOffsetVal = currOffsetVal - 10;
                  currLimitVal = currLimitVal - 10;

                  await fetchPreviousItems(
                      context, currOffsetVal, currLimitVal);
                }
                const SnackBar(
                  backgroundColor: Colors.orange,
                  content: Text(
                    'Fetching new items..',
                    style: TextStyle(color: Colors.white),
                  ),
                  duration: Duration(seconds: 2),
                );
                _refreshController.loadComplete();
              },
              onRefresh: () async {
                currOffsetVal += 10;
                currLimitVal += 10;

                print("Offset Value for replay : $currOffsetVal");
                print("Limit Value for replay : $currLimitVal");

                await fetchItems(currOffsetVal, currLimitVal, context);
                const SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(
                    'Fetching new items..',
                    style: TextStyle(color: Colors.white),
                  ),
                  duration: Duration(seconds: 2),
                );
                _refreshController.refreshCompleted();
              },
              controller: _refreshController,
              enablePullDown: true,
              enablePullUp: true,
              scrollDirection: Axis.vertical,
              child: ListView.builder(
                itemCount: l1.length,
                itemBuilder: (context, index) {
                  String m = l1[index]['message']!;
                  String t = l1[index]['timeStamp']!;

                  return ListTile(
                    hoverColor: Colors.yellow,
                    title: Text(
                      m,
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w500),
                    ),
                    subtitle: m == "SYS-DATA"
                        ? Text(
                            t,
                            style: const TextStyle(
                                fontSize: 20,
                                color: Colors.red,
                                fontWeight: FontWeight.w600),
                          )
                        : Text(
                            t,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 16, 4, 186),
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  );
                },
              ),
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }

          return const Center(
            child: Text("Neither error nor success!"),
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(
            Icons.add,
            color: Colors.black,
          ),
          onPressed: () {
            showModalBottomSheet(
                isDismissible: true,
                // isScrollControlled: true,
                enableDrag: true,
                context: context,
                builder: (context) {
                  return displayBottomSheet(context);
                });
          }),
    );
  }

  Future<void> fetchItems(
      int offsetVal, int limitVal, BuildContext context) async {
    l1.clear();
    await databaseInstance
        .fetchReplayList(offsetVal, limitVal)
        .then((response) {
      response.forEach((element) {
        Map<String, String> mp = {
          "message": element.message_,
          "timeStamp": element.timestamp
        };

        Future.delayed(const Duration(milliseconds: 100), () {
          l1.add(mp);
        });
      });
    }).whenComplete(() {
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          'Fetching new items..',
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(seconds: 2),
      );
    });
  }

  Future<void> fetchPreviousItems(
      BuildContext context, int offsetVal, int limitVal) async {
    l1.clear();
    await databaseInstance
        .fetchReplayList(offsetVal, limitVal)
        .then((response) {
      response.forEach((element) {
        Map<String, String> mp = {
          "message": element.message_,
          "timeStamp": element.timestamp
        };

        Future.delayed(Duration(milliseconds: 100), () {
          l1.add(mp);
        });
      });
    }).whenComplete(() {
      const SnackBar(
        backgroundColor: Colors.orange,
        content: Text(
          'Fetching previous items..',
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(seconds: 3),
      );
    });
  }

  Widget displayBottomSheet(BuildContext context) {
    TextEditingController _nameController = TextEditingController();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 12,
          ),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(hintText: 'Enter name'),
            keyboardType: TextInputType.name,
          ),
          SizedBox(
            height: 16,
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 10,
              right: 10,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: () {
                String nameVal = _nameController.text;
                print("log $nameVal");

                Map<String, String> temp = {
                  "message": nameVal,
                  "timeStamp": DateTime.now().toIso8601String()
                };

                r_userDataStreamController.add(temp);

                Navigator.of(context).pop();
              },
              child: Text(
                'done',
                style: TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}
