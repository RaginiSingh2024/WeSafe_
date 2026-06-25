import 'dart:async';

import 'package:background_location/background_location.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shake/shake.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:vibration/vibration.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:womensafteyhackfair/firebase_options.dart';
import 'package:womensafteyhackfair/cloud_service.dart';

// ** IMPORTANT INSTRUCTIONS **

// Hey there! :)
// I hope you will be doing great and I hope this code will help you in any way :)
// So all the other code is easy to understand because it 
// doesn't follow any complex architecture ;p so I didn't added any comments in it.
// Which are pretty importatnt to add when you are sharing your code. So you should 
// add comments in your code I am just a little lazy. 
//
// OK Back to the main topic. This file contains most of the core logic behind 
// the app's major functionality. I will try to explain every block in it so it will 
// be easy to follow along for you. Let's get started...

// So main functionality of the app is that it runs in background and detects or 
// listens for a phone shake and when that event happens it send sos message to 
// the selected contacts of the user.
// So main thing here is to set up a background isolate which will work in 
// background and will listen to shake events no matter the app is closed 
// or in background or foreground. 

// For that I have used ->  flutter_background_service: ^0.1.5
// Which is a very handy plugin to run our dart code in background.


// This function starts background isolates which is called when the app starts
// in main method and this will instantiate the background service and 
// then will listen  for updates. 
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase in background isolate
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init in background: $e");
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();

  service.on('action').listen((event) async {
    if (event == null) return;
    if (event["action"] == "setAsForeground") {
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }

      return;
    }

    if (event["action"] == "setAsBackground") {
      if (service is AndroidServiceInstance) {
        service.setAsBackgroundService();
      }
    }

    if (event["action"] == "stopService") {
      service.stopSelf();
    }
  });

  service.on('startSOSMode').listen((event) {
    BackgroundLocation.stopLocationService();
    BackgroundLocation.startLocationService(
      distanceFilter: 0,
    );
    debugPrint("Background Service: Emergency Precision Mode Activated (distanceFilter: 0).");
  });

  service.on('stopSOSMode').listen((event) {
    BackgroundLocation.stopLocationService();
    BackgroundLocation.startLocationService(
      distanceFilter: 20,
    );
    debugPrint("Background Service: Standard Precision Mode Restored (distanceFilter: 20).");
  });

  Location? _location;
// This is another handy plugin whcih works in background independently and fetches the 
// user location as we need location for some of the functionalities. Initially it will 
// show a notification to user that the service is running 
// this is important so that the user does know that the app is tracking his/her location.


  await BackgroundLocation.setAndroidNotification(
    title: "Location tracking is running in the background!",
    message: "You can turn it off from settings menu inside the app",
    icon: '@mipmap/ic_logo',
  );

  // This is where the location service gets started.
  BackgroundLocation.startLocationService(
    distanceFilter: 20,
  );

  // Its pretty easy to get location updates. As this method will only 
  // be called when there are some location updates. and will save the data 
  // in Shared Preferences. 

  // ** IMPORTANT CONCEPT ** 
  // When working with isolates we need to comunicate data through ports because unlike 
  // threads isolates does not share any memory.
  // Here I am usong shared preferences to save data because 
  // I dont need the data actively but need on specific time intervals. 
  // So instead for passing it to a port and listen to it continously I had managed it 
  // through shared preferences and worker plugin to get the updates after specific 
  // time when needed. 
  // Now you will think that it can be possible through ports too but why do it the hard 
  // way when it can be done easily :)
  // 
  BackgroundLocation.getLocationUpdates((location) async {
    _location = location;
    prefs.setStringList("location", [
      location.latitude?.toString() ?? "0.0",
      location.longitude?.toString() ?? "0.0"
    ]);

    // Dynamic backend sync in background
    try {
      final String email = prefs.getString('registered_email') ?? '';
      if (email.isNotEmpty && location.latitude != null && location.longitude != null) {
        await CloudService().updateLiveLocation(
          userEmail: email,
          latitude: location.latitude!,
          longitude: location.longitude!,
          accuracy: location.accuracy,
          speed: location.speed,
          heading: location.bearing,
        );
      }
    } catch (e) {
      debugPrint("Background sync Firestore error: $e");
    }
  });
  // Here I used screenShaker plugin to listen to shake events and I set the 
  // threshold to 7, to avoid unnecessery shakes which can be cause by mistake 
  // like when the phone is in purse or in hand while walking
  String screenShake = "Be strong, We are with you!";
  ShakeDetector.autoStart(

    // It deals with all the tests and then vibrates the phone so to let 
    // user know that shake was successful and sos has been generated
      shakeThresholdGravity: 7,
      onPhoneShake: (_) {
        Future(() async {
          print("Test 1");
          if (await Vibration.hasVibrator() == true) {
            print("Test 2");
            if (await Vibration.hasCustomVibrationsSupport() == true) {
              print("Test 3");
              Vibration.vibrate(duration: 1000);
            } else {
              print("Test 4");
              Vibration.vibrate();
              await Future.delayed(Duration(milliseconds: 500));
              Vibration.vibrate();
            }
            print("Test 5");
          }
          print("Test 6");
          String link = '';
          print("Test 7");
          try {
            double lat = _location?.latitude ?? 0.0;
            double long = _location?.longitude ?? 0.0;
            print("$lat ... $long");
            print("Test 9");
            link = "http://maps.google.com/?q=$lat,$long";
            SharedPreferences prefs = await SharedPreferences.getInstance();
            List<String> numbers = prefs.getStringList("numbers") ?? [];
            String error;
            try {
              if (numbers.isEmpty) {
                screenShake = "No contacs found, Please call 15 ASAP.";
                debugPrint(
                  'No Contacts Found!',
                );
                return;
              } else {
                for (int i = 0; i < numbers.length; i++) {
                  String phone = numbers[i];
                  if (phone.contains("***")) {
                    phone = phone.split("***")[1];
                  }
                  //Here I used telephony to send sms messages to the saved contacts. 
                  Telephony.backgroundInstance.sendSms(
                      to: phone, message: "Help Me! Track me here.\n$link");
                }
                prefs.setBool("alerted", true);
                screenShake = "SOS alert Sent! Help is on the way.";
              }
            } on PlatformException catch (e) {
              if (e.code == 'PERMISSION_DENIED') {
                error = 'Please grant permission';
                print('Error due to Denied: $error');
              }
              if (e.code == 'PERMISSION_DENIED_NEVER_ASK') {
                error = 'Permission denied- please enable it from app settings';
                print("Error due to not Asking: $error");
              }
            }
            print("Test 10");
            print(link);
          } catch (e) {
            print("Test 11");
            print(e);
          }
        });
      });
  print("Test 12");
  // on initial call to onStart() this will call which brings the background 
  // service to life
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }
  // Timer is placed so the background isolate can work every 
  // second unlike other worker managers
  Timer.periodic(Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Safe Shake activated!",
        content: screenShake,
      );
    }

    service.invoke(
      "update",
      {"current_date": DateTime.now().toIso8601String()},
    );
  });
}

//GET HOME SAFE _ WORK MANAGER SET TO 15 minutes frequency


// This fumction is attached to get home safe functionality 
// which will send the user location data to his/her selected 
// contact after every 15 minutes.

// Its simply a workManager which is executing a given task perioadically 
// afeter every 15 minutes


void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    String? contact = inputData?['contact'];
    if (contact == null) return false;
    final prefs = await SharedPreferences.getInstance();
    print(contact);
    List<String>? location = prefs.getStringList("location");
    if (location == null || location.length < 2) return false;
    String link = "http://maps.google.com/?q=${location[0]},${location[1]}";
    print(location);
    print(link);
    Telephony.backgroundInstance
        .sendSms(to: contact, message: "I am on my way! Track me here.\n$link");
    return true;
  });
}

// I hope this project have helped you
// And I am just happy that I have helped you in any way :)
// May your all wishes come true - Happy Fluttering <3