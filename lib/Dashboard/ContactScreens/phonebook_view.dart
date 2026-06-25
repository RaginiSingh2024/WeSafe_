import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:womensafteyhackfair/cloud_service.dart';
import 'package:womensafteyhackfair/Dashboard/Dashboard.dart';
import 'package:womensafteyhackfair/animations/bottomAnimation.dart';
import 'package:womensafteyhackfair/constants.dart';

class PhoneBook extends StatefulWidget {
  // final FirebaseUser user;
  // final bool contactAvailable;
  // final Function(bool) callback;

  // PhoneBook({this.user, this.contactAvailable, this.callback});

  @override
  _PhoneBookState createState() => _PhoneBookState();
}

class _PhoneBookState extends State<PhoneBook> {
  List<Contact>? _contacts;
  List<Contact>? filteredContacts;
  List<Contact> _userSelectedContacts = [];

  Permission _permission = Permission.contacts;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  Future<PermissionStatus> _getContactPermission() async {
    _permissionStatus = await _permission.status;

    if (_permissionStatus != PermissionStatus.granted) {
      _permissionStatus = await _permission.request();
      return _permissionStatus;
    } else {
      return _permissionStatus;
    }
  }

  refreshContacts() async {
    if (kIsWeb) {
      // No dummy contacts preloaded. Real user-created contacts can be added manually.
      setState(() {
        _contacts = [];
        filteredContacts = [];
      });
      return;
    }

    try {
      PermissionStatus permissionStatus = await _getContactPermission();
      if (permissionStatus == PermissionStatus.granted) {
        var contacts = (await ContactsService.getContacts(
          withThumbnails: false,
        ))
            .toList();
        setState(() {
          _contacts = contacts;
          filteredContacts = _contacts;
        });
      } else {
        // Fallback to empty list so it doesn't spin forever, and show warning
        setState(() {
          _contacts = [];
          filteredContacts = [];
        });
        Fluttertoast.showToast(
          msg: "Contact permission denied.",
          backgroundColor: AppColors.emergency,
        );
      }
    } catch (e) {
      debugPrint("Error loading contacts: $e");
      setState(() {
        _contacts = [];
        filteredContacts = [];
      });
      Fluttertoast.showToast(
        msg: "Failed to load contacts: $e",
        backgroundColor: AppColors.emergency,
      );
    }
  }

  void _handleInvalidPermissions(PermissionStatus permissionStatus) {
    if (permissionStatus == PermissionStatus.denied) {
      throw new PlatformException(
          code: "PERMISSION_DENIED",
          message: "Access to location data denied",
          details: null);
    }
  }

  @override
  initState() {
    super.initState();
    refreshContacts();
  }

  goBack() async {
    // checkFor contacts existance
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => Dashboard(
                  pageIndex: 1,
                )),
        (route) => false);
  }

  saveContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) {
      Fluttertoast.showToast(msg: "Please sign in to save contacts.");
      return;
    }

    if (_userSelectedContacts.isNotEmpty) {
      for (Contact c in _userSelectedContacts) {
        String name = c.displayName ?? "User";
        String phone = "";
        if (c.phones != null && c.phones!.isNotEmpty) {
          phone = refactorPhoneNumbers(c.phones!.first.value);
        }
        await CloudService().addEmergencyContact(uid, name, phone);
      }

      Fluttertoast.showToast(msg: "Contacts have been saved successfully!");
      goBack();
    } else {
      Fluttertoast.showToast(msg: "Please add at least one contact");
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.lightBackground, AppColors.mutedBlushLavender],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: saveContacts,
          backgroundColor: AppColors.primaryDark,
          icon: const Icon(Icons.check_rounded, color: Colors.white),
          label: Text(
            "Save List",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryDark),
            onPressed: () {
              goBack();
            },
          ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
            ),
            child: TextField(
              textInputAction: TextInputAction.search,
              style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 15),
              cursorColor: AppColors.primaryDark,
              decoration: InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPurple, size: 20),
                  hintText: 'Search Name',
                  hintStyle: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 15)),
              onChanged: (string) {
                setState(() {
                  filteredContacts = _contacts
                      ?.where((c) => ((c.displayName ?? "")
                          .toLowerCase()
                          .contains(string.toLowerCase())))
                      .toList();
                });
              },
            ),
          ),
        ),
        body: _contacts != null
            ? Container(
                height: height,
                width: width,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: height * 0.01, horizontal: 16.0),
                  separatorBuilder: (context, index) {
                    Contact? c = filteredContacts?.elementAt(index);
                    if (c == null || c.phones == null || c.phones!.isEmpty) {
                      return const SizedBox();
                    }
                    return const SizedBox(height: 8);
                  },
                  itemCount: filteredContacts?.length ?? 0,
                  itemBuilder: (BuildContext context, int index) {
                    Contact? c = filteredContacts?.elementAt(index);
                    if (c == null) return const SizedBox();
                    return ItemsTile(addToContacts, c, c.phones);
                  },
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryPurple)),
              ),
      ),
    );
  }

  addToContacts(Contact con) {
    print(con.phones);
    bool alreadyInList = false;
    for (Contact c in _userSelectedContacts) {
      print("INside contacts: ID: ${c.displayName}");
      if (c.displayName != null && c.displayName != "") {
        if (c.displayName == con.displayName) {
          alreadyInList = true;
          break;
        }
      } else {
        if (c.phones != null && c.phones!.isNotEmpty) {
          if (c.phones!.contains(con.phones?.first)) {
            alreadyInList = true;
            break;
          }
        }
      }
    }
    if (!alreadyInList) {
      _userSelectedContacts.add(con);
      Fluttertoast.showToast(
          msg: "${_userSelectedContacts.length} contacts selected");
    } else {
      Fluttertoast.showToast(msg: "Already in your selected List");
    }
  }

  String refactorPhoneNumbers(String? phone) {
    if (phone == null || phone == "") {
      return "";
    }
    var newPhone = phone.replaceAll(RegExp(r"[^\name\w]"), '');
    if (newPhone.length == 12) {
      newPhone = "+" + newPhone.substring(0, newPhone.length);
    }
    if (newPhone.length == 11) {
      newPhone = "+92" + newPhone.substring(1, newPhone.length);
    }
    if (newPhone.length > 12) {
      var start2Number = newPhone.substring(0, 2);
      if (start2Number == "92") {
        newPhone = "+" + newPhone.substring(0, 12);
      }
      if (start2Number == "03") {
        newPhone = "+92" + newPhone.substring(1, newPhone.length);
      }
    }

    return newPhone;
  }
}

class ItemsTile extends StatefulWidget {
  ItemsTile(this.addToContacts, this.c, this._items);
  final Function addToContacts;
  final Contact c;
  final Iterable<Item>? _items;

  @override
  _ItemsTileState createState() => _ItemsTileState();
}

class _ItemsTileState extends State<ItemsTile> {
  String currentContact = '';

  @override
  void initState() {
    super.initState();

    currentContact = '';
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    if (currentContact.isNotEmpty) {
      currentContact = '';
    }
    final items = widget._items;
    return items == null || items.isEmpty
        ? const SizedBox()
        : WidgetAnimator(
            Container(
              decoration: AppColors.glassDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  onTap: () {
                    widget.addToContacts(widget.c);
                    FocusScopeNode currentFocus = FocusScope.of(context);
  
                    if (!currentFocus.hasPrimaryFocus) {
                      currentFocus.unfocus();
                    }
                  },
                  leading: CircleAvatar(
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
                      radius: height * 0.025,
                      child: Text(
                          widget.c.displayName != null && widget.c.displayName!.isNotEmpty
                              ? '${widget.c.displayName![0]}'.toUpperCase()
                              : 'U',
                          style: GoogleFonts.poppins(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.c.displayName ?? "",
                        style: GoogleFonts.poppins(
                            color: AppColors.textDark, fontSize: height * 0.020, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: items.map((i) {
                          final val = i.value ?? "";
                          if (currentContact == val.replaceAll(" ", "")) {
                            return const SizedBox();
                          }
                          currentContact = val.replaceAll(" ", "");
                          return Text(
                            i.value ?? i.label ?? "",
                            style: GoogleFonts.shareTechMono(color: AppColors.mutedText, fontSize: 13, fontWeight: FontWeight.w500),
                          );
                        }).toList())
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Tap',
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
  }
}

// uploadContact.name = widget.c.displayName;
//             var phoneNumber =
//                 widget._items.map((i) => i.value ?? " ").toString();
