import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/constants.dart';

class ChangePinScreen extends StatefulWidget {
  final int? pin;
  const ChangePinScreen({Key? key, this.pin}) : super(key: key);

  @override
  _ChangePinScreenState createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final TextEditingController _pinPutController1 = TextEditingController();
  final FocusNode _pinPutFocusNode1 = FocusNode();
  final TextEditingController _pinPutController2 = TextEditingController();
  final FocusNode _pinPutFocusNode2 = FocusNode();
  String currentPin = "";
  bool pinChanged = false;

  BoxDecoration get _pinPutDecoration {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.4),
      borderRadius: BorderRadius.circular(15.0),
      border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.01),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  BoxDecoration get _pinPutFocusedDecoration {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.7),
      borderRadius: BorderRadius.circular(15.0),
      border: Border.all(color: AppColors.primaryDark, width: 2),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDark.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: GoogleFonts.shareTechMono(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
      decoration: _pinPutDecoration,
    );

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
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: AppColors.primaryDark,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                Navigator.pop(context);
              }),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Text(
                widget.pin == -1111 ? "Create PIN" : "Change PIN",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryPurple.withOpacity(0.15)),
                ),
                child: Image.asset(
                  "assets/pin.png",
                  height: 70,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Visibility(
              visible: widget.pin != -1111,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 35.0, right: 20),
                    child: Row(
                      children: [
                        Text(
                          "Current Pin",
                          style: GoogleFonts.poppins(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            indent: 10,
                            endIndent: 20,
                            color: AppColors.textDark.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20.0),
                    padding: const EdgeInsets.all(20.0),
                    child: Pinput(
                      length: 4,
                      onCompleted: (String pin) {
                        currentPin = pin;
                        _pinPutFocusNode1.unfocus();
                      },
                      focusNode: _pinPutFocusNode1,
                      controller: _pinPutController1,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: defaultPinTheme.copyWith(
                        decoration: _pinPutFocusedDecoration,
                      ),
                      submittedPinTheme: defaultPinTheme.copyWith(
                        decoration: _pinPutDecoration.copyWith(
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 35.0, right: 20),
              child: Row(
                children: [
                  Text(
                    "New Pin",
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      indent: 10,
                      endIndent: 20,
                      color: AppColors.textDark.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              padding: const EdgeInsets.all(20.0),
              child: Pinput(
                length: 4,
                onCompleted: (String pin) => _showSnackBar(pin, context),
                focusNode: _pinPutFocusNode2,
                controller: _pinPutController2,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: _pinPutFocusedDecoration,
                ),
                submittedPinTheme: defaultPinTheme.copyWith(
                  decoration: _pinPutDecoration.copyWith(
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Visibility(
                visible: pinChanged,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).removeCurrentSnackBar();
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 56,
                        width: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primaryPurple],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "Done",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ))
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String pin, BuildContext context) {
    if (widget.pin != -1111) {
      if (currentPin.isEmpty || currentPin.length != 4) {
        Fluttertoast.showToast(msg: 'Please enter Current PIN');
        _pinPutFocusNode2.unfocus();
        return;
      }
      if (currentPin != widget.pin.toString()) {
        final snackBar = SnackBar(
          duration: const Duration(seconds: 10),
          content: Container(
            height: 20.0,
            child: Center(
              child: Text(
                'Current Pin doesnt match! Please try again.',
                style: const TextStyle(fontSize: 16.0),
              ),
            ),
          ),
          backgroundColor: AppColors.accent,
        );

        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      } else {
        changePinSnakBar(pin);
      }
    } else {
      changePinSnakBar(pin);
    }
  }

  void changePin(int parse) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt("pin", parse);
  }

  void changePinSnakBar(pin) {
    final snackBar = SnackBar(
      duration: const Duration(seconds: 10),
      content: Container(
        height: 20.0,
        child: Center(
          child: Text(
            'Pin Changed. Value: $pin',
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
      ),
      backgroundColor: AppColors.accent,
    );
    changePin(int.parse(pin));
    setState(() {
      pinChanged = true;
    });
    _pinPutController1.clear();
    _pinPutController2.clear();
    _pinPutFocusNode1.unfocus();
    _pinPutFocusNode2.unfocus();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
