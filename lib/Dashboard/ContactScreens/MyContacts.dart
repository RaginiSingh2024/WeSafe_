import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:womensafteyhackfair/cloud_service.dart';

import 'package:womensafteyhackfair/constants.dart';

class MyContactsScreen extends StatefulWidget {
  const MyContactsScreen({Key? key}) : super(key: key);

  @override
  _MyContactsScreenState createState() => _MyContactsScreenState();
}

class _MyContactsScreenState extends State<MyContactsScreen> {
  String get userId => FirebaseAuth.instance.currentUser?.uid ?? "";

  void _showAddManualContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Add Manual Contact",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: GoogleFonts.poppins(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: "Contact Name",
                  labelStyle: GoogleFonts.poppins(color: AppColors.mutedText),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPurple)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.poppins(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  labelStyle: GoogleFonts.poppins(color: AppColors.mutedText),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPurple)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Phone number is required" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.poppins(color: AppColors.mutedText, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (userId.isNotEmpty) {
                await CloudService().addEmergencyContact(
                  userId,
                  nameController.text.trim(),
                  phoneController.text.trim(),
                );
                Fluttertoast.showToast(msg: "Contact Saved Successfully!");
                Navigator.pop(context);
              }
            },
            child: Text("SAVE", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(String contactId, String currentName, String currentPhone) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Edit Contact",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: GoogleFonts.poppins(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: "Contact Name",
                  labelStyle: GoogleFonts.poppins(color: AppColors.mutedText),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPurple)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.poppins(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  labelStyle: GoogleFonts.poppins(color: AppColors.mutedText),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPurple)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Phone number is required" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.poppins(color: AppColors.mutedText, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (userId.isNotEmpty) {
                await CloudService().updateEmergencyContact(
                  userId,
                  contactId,
                  nameController.text.trim(),
                  phoneController.text.trim(),
                );
                Fluttertoast.showToast(msg: "Contact Updated Successfully!");
                Navigator.pop(context);
              }
            },
            child: Text("UPDATE", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text("Please sign in to view contacts."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SECURE CHANNELS",
                style: GoogleFonts.poppins(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "SOS Contacts",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 12.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
                ),
                child: const Icon(Icons.add, color: AppColors.primaryDark, size: 20),
              ),
              onPressed: _showAddManualContactDialog,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: CloudService().streamEmergencyContacts(userId),
        builder: (context, AsyncSnapshot<QuerySnapshot> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple)),
            );
          }

          if (snap.hasData && snap.data != null && snap.data!.docs.isNotEmpty) {
            final docs = snap.data!.docs;
            return Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.mutedBlushLavender.withOpacity(0.5),
                          endIndent: 12,
                        ),
                      ),
                      Text(
                        "Swipe left to delete, right to edit",
                        style: GoogleFonts.poppins(
                          color: AppColors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.mutedBlushLavender.withOpacity(0.5),
                          indent: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final docId = doc.id;
                      final name = doc['name'] as String? ?? "Unknown";
                      final phone = doc['phone'] as String? ?? "";

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Slidable(
                          key: ValueKey(docId),
                          startActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            extentRatio: 0.25,
                            children: [
                              SlidableAction(
                                label: 'Edit',
                                backgroundColor: AppColors.primaryPurple,
                                foregroundColor: Colors.white,
                                icon: Icons.edit_rounded,
                                onPressed: (context) {
                                  _showEditContactDialog(docId, name, phone);
                                },
                              ),
                            ],
                          ),
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            extentRatio: 0.25,
                            children: [
                              SlidableAction(
                                label: 'Delete',
                                backgroundColor: AppColors.emergency,
                                foregroundColor: Colors.white,
                                icon: Icons.delete_rounded,
                                onPressed: (context) async {
                                  await CloudService().deleteEmergencyContact(userId, docId);
                                  Fluttertoast.showToast(
                                    msg: "$name removed!",
                                    backgroundColor: AppColors.emergency,
                                  );
                                },
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: AppColors.glassDecoration(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.softLavender.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.softLavender,
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    phone,
                                    style: GoogleFonts.shareTechMono(
                                      color: AppColors.primaryPurple,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    color: AppColors.successGreen,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          } else {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.6)),
                      ),
                      child: Icon(
                        Icons.people_outline_rounded,
                        color: AppColors.primaryPurple.withOpacity(0.5),
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "No SOS Contacts",
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Add trusted contacts to notify them immediately when SOS is triggered.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.mutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primaryPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(
                          "ADD CONTACT",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: _showAddManualContactDialog,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
