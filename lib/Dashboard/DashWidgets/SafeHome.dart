import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:womensafteyhackfair/Dashboard/DashWidgets/WeSafeToast.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/Dashboard/ContactScreens/phonebook_view.dart';
import 'package:workmanager/workmanager.dart';

class SafeHome extends StatefulWidget {
  const SafeHome({Key? key}) : super(key: key);

  @override
  _SafeHomeState createState() => _SafeHomeState();
}

class _SafeHomeState extends State<SafeHome> {
  bool getHomeSafeActivated = false;
  List<String> numbers = [];

  checkGetHomeActivated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      getHomeSafeActivated = prefs.getBool("getHomeSafe") ?? false;
    });
  }

  changeStateOfHomeSafe(value) async {
    if (value) {
      WeSafeToast.showSuccess(
        title: 'Service Activated',
        message: 'Get Home Safe location sharing is running in background.',
        status: 'ACTIVE',
      );
    } else {
      WeSafeToast.showSuccess(
        title: 'Service Disabled',
        message: 'Get Home Safe location sharing has been disabled.',
      );
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      getHomeSafeActivated = value;
      prefs.setBool("getHomeSafe", value);
    });
  }

  @override
  void initState() {
    super.initState();

    checkGetHomeActivated();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
      child: InkWell(
        onTap: () {
          showModelSafeHome(getHomeSafeActivated);
        },
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            height: 180,
            width: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ListTile(
                        title: Text("Get Home Safe"),
                        subtitle: Text("Share Location Periodically"),
                      ),
                      Visibility(
                        visible: getHomeSafeActivated,
                        child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Row(
                              children: [
                                SpinKitDoubleBounce(
                                  color: Colors.red,
                                  size: 15,
                                ),
                                SizedBox(width: 15),
                                Text("Currently Running...",
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 10)),
                              ],
                            )),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      "assets/route.jpg",
                      height: 140,
                    ))
              ],
            ),
          ),
        ),
      ),
    );
  }

  showModelSafeHome(bool processRunning) async {
    int selectedContact = -1;
    bool getHomeActivated = processRunning;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? activeContactPhone = prefs.getString("getHomeSafeContact");

    showModalBottomSheet(
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isScrollControlled: true,
        isDismissible: true,
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height / 1.4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: Divider(
                            indent: 20,
                            endIndent: 20,
                          )),
                          Text("Get Home Safe"),
                          Expanded(
                              child: Divider(
                            indent: 20,
                            endIndent: 20,
                          )),
                        ],
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Color(0xFFF5F4F6)),
                      child: SwitchListTile(
                        secondary: Lottie.asset("assets/routes.json"),
                        value: getHomeActivated,
                        onChanged: (val) async {
                          if (val && selectedContact == -1) {
                            WeSafeToast.showWarning(
                              title: 'No Contact Selected',
                              message: 'Please select one contact from the list!',
                            );
                            return;
                          }
                          if (kIsWeb) {
                            WeSafeToast.showWarning(
                              title: 'Platform Unsupported',
                              message: 'Get Home Safe periodic tasks are not supported on Web.',
                            );
                            setModalState(() {
                              getHomeActivated = false;
                            });
                            return;
                          }
                          setModalState(() {
                            getHomeActivated = val;
                          });
                          if (getHomeActivated) {
                            changeStateOfHomeSafe(true);
                            String selectedPhone = numbers[selectedContact].split("***")[1];
                            await prefs.setString("getHomeSafeContact", selectedPhone);
                            Workmanager().registerPeriodicTask(
                              "3",
                              "simplePeriodicTask",
                              tag: "3",
                              inputData: {
                                "contact": selectedPhone
                              },
                              frequency: Duration(minutes: 15),
                            );
                          } else {
                            changeStateOfHomeSafe(false);
                            await prefs.remove("getHomeSafeContact");
                            await Workmanager().cancelByTag("3");
                          }
                        },
                        subtitle: Text(
                            "Your location will be shared with one of your contacts every 15 minutes"),
                      ),
                    ),
                    Expanded(
                        child: FutureBuilder<List<String>>(
                            future: getSOSNumbers(),
                            builder: (context,
                                AsyncSnapshot<List<String>> snapshot) {
                              if (snapshot.hasData &&
                                  snapshot.data != null &&
                                  snapshot.data!.isNotEmpty) {
                                if (selectedContact == -1 && activeContactPhone != null) {
                                  selectedContact = snapshot.data!.indexWhere(
                                      (item) => item.split("***")[1] == activeContactPhone);
                                }
                                return ListView.separated(
                                    itemCount: snapshot.data!.length,
                                    separatorBuilder: (context, index) {
                                      return Divider(
                                        indent: 20,
                                        endIndent: 20,
                                      );
                                    },
                                    itemBuilder: (context, index) {
                                      String contactData = snapshot.data![index];
                                      return ListTile(
                                        onTap: () async {
                                          setModalState(() {
                                            selectedContact = index;
                                          });
                                          if (getHomeActivated) {
                                            String selectedPhone = contactData.split("***")[1];
                                            await prefs.setString("getHomeSafeContact", selectedPhone);
                                            await Workmanager().registerPeriodicTask(
                                              "3",
                                              "simplePeriodicTask",
                                              tag: "3",
                                              inputData: {
                                                "contact": selectedPhone
                                              },
                                              frequency: Duration(minutes: 15),
                                            );
                                            WeSafeToast.showSuccess(
                                              title: 'Contact Updated',
                                              message: 'Get Home Safe location sharing updated to new contact.',
                                            );
                                          }
                                        },
                                        leading: CircleAvatar(
                                          backgroundImage:
                                              AssetImage("assets/user.png"),
                                        ),
                                        title:
                                            Text(contactData.split("***")[0]),
                                        subtitle:
                                            Text(contactData.split("***")[1]),
                                        trailing: selectedContact == index
                                            ? Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                              )
                                            : null,
                                      );
                                    });
                              } else {
                                return ListTile(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PhoneBook(),
                                      ),
                                    );
                                  },
                                  title: Text("No contact found!"),
                                  subtitle:
                                      Text("Please add atleast one Contact"),
                                  trailing: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.grey),
                                );
                              }
                            }))
                  ],
                ),
              );
            },
          );
        });
  }

  Future<List<String>> getSOSNumbers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    numbers = prefs.getStringList("numbers") ?? [];

    return numbers;
  }
}
