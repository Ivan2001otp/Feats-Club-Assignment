import 'dart:async';
import 'dart:core';
import 'dart:math';
import 'package:assignment/Database/db.instance.dart';
import 'package:assignment/Database/db_util.dart';
import 'package:assignment/data/system.data.dart';
import 'package:assignment/data/user.data.dart';
import 'package:assignment/model/data.model.dart';
import 'package:assignment/replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';

/*
  -two uniq streams
  -merge streams
  -Appending at the top..(latest items at top)
  -onRefresh it should give me immediate next items-10.(on every refresh attempt)
  -When we go off screen , dispclay the new items..
 */

final systemDataGenerator = Stream.periodic(Duration(seconds: 1), (_) {
  return {"timeStamp": DateTime.now().toIso8601String(), "message": 'SYS-DATA'};
}).asBroadcastStream();

final autoUserDataGenerator = Stream.periodic(Duration(seconds: 3), (_) {
  return {"Name": 'User Data here..'};
}).asBroadcastStream();

late UtilDB databaseInstance;

void main() async {
  databaseInstance = UtilDB();
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  //Streams -> db -> filter -> UI
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'BehaviorSubject'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  //pagination
  int noOfItems = 0; //this is 10 for every page
  int currPage = 0; //currpage -> 10 items.
  int itemLimit = 10;

  int currOffsetVal = 0;
  int currLimitVal = 10;

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  ScrollController _scrollController = ScrollController();

  StreamController<Map<String, String>> userDataStreamController =
      StreamController();

  late Stream<Map<String, String>> userDataStream;

  final behaviorSubjectItems = BehaviorSubject<List<Map<String, String>>>();

  Map<String, String> initialData = {"Name": "No name", "Usn": "no usn"};

  List<Map<String, String>> l1 = List.empty(growable: true);

  late List<DataModel> cache;
  bool isFirstAttemptRefresh = false;
  List<Map<String, String>> bufferList = List.empty(growable: true);

  @override
  void initState() {
    userDataStream = userDataStreamController.stream.asBroadcastStream();
    //merge the two streams..
    final bufferedItems =
        Rx.merge([userDataStream, systemDataGenerator]).bufferCount(2);

    bufferedItems.listen((event) {
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
      behaviorSubjectItems.add(data);
    });

    /*
    Rx.merge([userDataStream, systemDataGenerator])
        .distinctUnique()
        .bufferTime(duration)
        .map(
          //[1,2..10]
          (events) => events.toList()
            ..sort(
              (a, b) {
                //convert string to int of timestamp value
                DateTime t1 = DateTime.parse(a['timeStamp']!);
                DateTime t2 = DateTime.parse(b['timeStamp']!);

                return t1.compareTo(t2);
              },
            ),
        )
        .forEach((element) {
      behaviorSubjectItems.add(element);
    });*/

    // behaviorSubjectItems.addStream(sortedStreamItems);

    // behaviorSubjectItems.listen((value) {
    // if (noOfItems <= itemLimit) {
    //   noOfItems++;
    //   l1.add(value);
    // }
    behaviorSubjectItems.listen((value) {
      /*
      id = map['_colId'];
    message = map['_data'];
    timeForData = map['_timeStamp'];
       */
      value.forEach((element) async {
        String message_temp = element['message']!;

        String time_temp = element['timeStamp']!;

        DataModel dataModel = DataModel(message_temp, time_temp);
        int res = await databaseInstance.insertItem(dataModel);

        if (currPage < 10) {
          l1.add({"message": message_temp, "timeStamp": time_temp});
          currPage++;
        }
        // print('Inserted val->$res');
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    print('log-ondispose executed!');
    // TODO: implement dispose
    super.dispose();
    userDataStream.listen(null);
    behaviorSubjectItems.listen(null);
    _refreshController.dispose();
    userDataStreamController.close();
    behaviorSubjectItems.close();
    databaseInstance.clearDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        floatingActionButton: FloatingActionButton(
            child: const Icon(
              Icons.add,
              color: Colors.black,
            ),
            onPressed: () {
              showModalBottomSheet(
                  isDismissible: true,
                  enableDrag: true,
                  context: context,
                  builder: (context) {
                    return displayBottomSheet(context);
                  });
            }),
        appBar: AppBar(
          elevation: 0.0,
          backgroundColor: Colors.deepPurple,
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ReplayWidget()),
                );
              },
              icon: Icon(
                Icons.arrow_right_alt,
                color: Colors.white,
                size: 24,
              ),
            )
          ],
          title: Text(
            widget.title,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: StreamBuilder(
          stream: behaviorSubjectItems.stream,
          builder: (context, snapshot) {
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
                  print("Offset Value : $currOffsetVal");
                  print("Limit Value: $currLimitVal");
                  _refreshController.loadComplete();
                },
                enablePullUp: true,
                onRefresh: () async {
                  currOffsetVal += 10;
                  currLimitVal += 10;

                  print("Offset Value : $currOffsetVal");
                  print("Limit Value: $currLimitVal");

                  await fetchItems(currOffsetVal, currLimitVal, context);
                  _refreshController.refreshCompleted();
                },
                controller: _refreshController,
                enablePullDown: true,
                scrollDirection: Axis.vertical,
                child: ListView.builder(
                    itemCount: l1.length,
                    itemBuilder: (context, index) {
                      // print(cache[index].message);

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
                    }),
              );
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.red,
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Text(snapshot.error.toString()),
              );
            }

            return const Center(
              child: Text('Neither error nor success!'),
            );
          },
        )

        /* 
       SmartRefresher(
        enablePullDown: true,
        // enablePullUp: true,
        controller: _refreshController,
        onRefresh: () async {
          Future.delayed(Duration(seconds: 3), () async {
            await _fetchData();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fetching new items from stream'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                //system data and user data

                //past immediate events.
                StreamBuilder(
                    stream: Stream.f
                   , builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    // if (noOfItems < itemLimit) {
                    //   noOfItems += 2;
                    //   // cache.addAll(snapshot.data!);
                    //   cache = cache + snapshot.data!;
                    // }
                    cache.addAll(snapshot.data!);

                    return ListView.builder(
                        scrollDirection: Axis.vertical,
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        itemCount: cache.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          if (cache[index]['Name'] != null) {
                            return Text(
                              '${index + 1}-user data-> ${cache[index]['Name']!}',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.red,
                              ),
                            );
                          }
                          return Text(
                            '${index + 1}-sys data -> ${cache[index]['timeStamp']!}',
                            style: TextStyle(fontSize: 18),
                          );
                        });
                  }
                  if (snapshot.hasError) {
                    return Text(
                      snapshot.error.toString(),
                      style: TextStyle(fontSize: 16),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      margin: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: const Center(
                          child: CircularProgressIndicator(
                        color: Colors.red,
                      )),
                    );
                  }
                  return Text(
                    'Nothing',
                    style: TextStyle(fontSize: 16),
                  );
                })
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          child: const Icon(
            Icons.add,
            color: Colors.black,
          ),
          onPressed: () {
            showModalBottomSheet(
                isDismissible: true,
                enableDrag: true,
                context: context,
                builder: (context) {
                  return displayBottomSheet(context);
                });
          }),
   */

        );
  }

  Future<void> fetchPreviousItems(
      BuildContext context, int offsetVal, int limitVal) async {
    l1.clear(); //clears the list.-> to add the previous items
    await databaseInstance.fetchList(offsetVal, limitVal).then((response) {
      response.forEach((element) {
        Map<String, String> mp = {
          "message": element.message_,
          "timeStamp": element.timestamp
        };

        //just added minute delay.
        Future.delayed(Duration(milliseconds: 800), () {
          l1.add(mp);
        });
      });
    }).whenComplete(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            'Fetching previous items..',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> fetchItems(
      int offsetVal, int limitVal, BuildContext context) async {
    l1.clear(); //erases the 20 items holded in it.
    await databaseInstance.fetchList(offsetVal, limitVal).then((response) {
      response.forEach((element) {
        Map<String, String> mp = {
          "message": element.message_,
          "timeStamp": element.timestamp
        };

        //just added a minute delay
        Future.delayed(Duration(milliseconds: 800), () {
          l1.add(mp);
        });
      });
    }).whenComplete(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Fetching new items..',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
        ),
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
                backgroundColor: Colors.deepPurple,
              ),
              onPressed: () {
                String nameVal = _nameController.text;
                print("log $nameVal");

                Map<String, String> temp = {
                  "Name": nameVal,
                  "message": nameVal,
                  "timeStamp": '${DateTime.now()}'
                };
                userDataStreamController.add(temp);

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
