import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:womensafteyhackfair/Dashboard/Dashboard.dart';
import 'package:womensafteyhackfair/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple)),
      ),
    );

    if (_isSignUp) {
      try {
        final email = _emailController.text.trim().toLowerCase();
        final password = _passwordController.text;
        final name = _usernameController.text.trim();
        final phone = _phoneController.text.trim();

        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final user = userCredential.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': name,
            'phoneNumber': phone,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });

          await prefs.setString("user_uid", user.uid);
          await prefs.setString("registered_username", name);
          await prefs.setString("registered_email", email);
          await prefs.setString("registered_phone", phone);
          await prefs.setBool("is_logged_in", true);

          Navigator.pop(context); // Pop loading spinner

          Fluttertoast.showToast(
            msg: "Registration Successful!",
            backgroundColor: AppColors.secondary,
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Dashboard()),
          );
        } else {
          Navigator.pop(context); // Pop loading spinner
          Fluttertoast.showToast(
            msg: "Failed to create user account.",
            backgroundColor: Colors.red,
          );
        }
      } on FirebaseAuthException catch (e) {
        Navigator.pop(context); // Pop loading spinner
        String errorMsg;
        switch (e.code) {
          case 'weak-password':
            errorMsg = 'Password is too weak. Use at least 6 characters.';
            break;
          case 'email-already-in-use':
            errorMsg = 'An account already exists with this email.';
            break;
          case 'invalid-email':
            errorMsg = 'Please enter a valid email address.';
            break;
          default:
            errorMsg = e.message ?? 'Registration failed. Please try again.';
        }
        Fluttertoast.showToast(
          msg: errorMsg,
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      } catch (e) {
        Navigator.pop(context); // Pop loading spinner
        Fluttertoast.showToast(
          msg: "Registration error: ${e.toString()}",
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } else {
      try {
        final email = _emailController.text.trim().toLowerCase();
        final password = _passwordController.text;

        final userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        final user = userCredential.user;
        if (user != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          String name = "User";
          String phone = "";
          if (doc.exists && doc.data() != null) {
            name = doc.data()?['name'] ?? "User";
            phone = doc.data()?['phoneNumber'] ?? "";
          }

          await prefs.setString("user_uid", user.uid);
          await prefs.setString("registered_username", name);
          await prefs.setString("registered_email", email);
          await prefs.setString("registered_phone", phone);
          await prefs.setBool("is_logged_in", true);

          Navigator.pop(context); // Pop loading spinner

          Fluttertoast.showToast(
            msg: "Welcome back, $name!",
            backgroundColor: AppColors.secondary,
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Dashboard()),
          );
        } else {
          Navigator.pop(context); // Pop loading spinner
          Fluttertoast.showToast(
            msg: "Failed to authenticate.",
            backgroundColor: Colors.red,
          );
        }
      } on FirebaseAuthException catch (e) {
        Navigator.pop(context); // Pop loading spinner
        String errorMsg;
        switch (e.code) {
          case 'user-not-found':
            errorMsg = 'No account found with this email. Please sign up.';
            break;
          case 'wrong-password':
            errorMsg = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            errorMsg = 'Please enter a valid email address.';
            break;
          case 'user-disabled':
            errorMsg = 'This account has been disabled.';
            break;
          case 'invalid-credential':
            errorMsg = 'Invalid email or password.';
            break;
          default:
            errorMsg = e.message ?? 'Sign in failed. Please try again.';
        }
        Fluttertoast.showToast(
          msg: errorMsg,
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      } catch (e) {
        Navigator.pop(context); // Pop loading spinner
        Fluttertoast.showToast(
          msg: "Sign in error: ${e.toString()}",
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.lightBackground, AppColors.mutedBlushLavender],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Subtle soft glows
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softLavender.withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryPurple.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Main Body
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo & Header
                      Hero(
                        tag: 'appLogo',
                        child: Image.asset(
                          "assets/wesafelogo.png",
                          height: 140,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "WESAFE",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp ? "Create a new account" : "Sign in to continue",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Form Fields Card with soft glassmorphism
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  // Username field (Sign Up only)
                                  if (_isSignUp) ...[
                                    TextFormField(
                                      controller: _usernameController,
                                      textInputAction: TextInputAction.next,
                                      style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        labelText: "Username",
                                        labelStyle: const TextStyle(color: AppColors.mutedText),
                                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryPurple),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.4),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: AppColors.softLavender, width: 2),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return "Please enter a username";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // Phone Number field (Sign Up only)
                                  if (_isSignUp) ...[
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        labelText: "Phone Number",
                                        labelStyle: const TextStyle(color: AppColors.mutedText),
                                        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primaryPurple),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.4),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: AppColors.softLavender, width: 2),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return "Please enter a phone number";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // Email field
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      labelText: "Email Address",
                                      labelStyle: const TextStyle(color: AppColors.mutedText),
                                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryPurple),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.4),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: AppColors.softLavender, width: 2),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return "Please enter your email";
                                      }
                                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                      if (!emailRegex.hasMatch(val.trim())) {
                                        return "Please enter a valid email address";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Password field
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
                                    onFieldSubmitted: (_) => _isSignUp ? null : _submit(),
                                    style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      labelText: "Password",
                                      labelStyle: const TextStyle(color: AppColors.mutedText),
                                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryPurple),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: AppColors.primaryPurple,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.4),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: AppColors.softLavender, width: 2),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return "Please enter a password";
                                      }
                                      if (val.length < 6) {
                                        return "Password must be at least 6 characters";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Confirm Password field (Sign Up only)
                                  if (_isSignUp) ...[
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        labelText: "Confirm Password",
                                        labelStyle: const TextStyle(color: AppColors.mutedText),
                                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryPurple),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            color: AppColors.primaryPurple,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword = !_obscureConfirmPassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.4),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: AppColors.softLavender, width: 2),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) {
                                          return "Please confirm your password";
                                        }
                                        if (val != _passwordController.text) {
                                          return "Passwords do not match";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                  ],

                                  // Action Button with Gradient
                                  Container(
                                    width: double.infinity,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.primaryDark, AppColors.primaryPurple],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryDark.withOpacity(0.25),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: _submit,
                                      child: Text(
                                        _isSignUp ? "SIGN UP" : "SIGN IN",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Toggle Text Button
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _formKey.currentState?.reset();
                            _usernameController.clear();
                            _phoneController.clear();
                            _emailController.clear();
                            _passwordController.clear();
                            _confirmPasswordController.clear();
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
                            children: [
                              TextSpan(
                                text: _isSignUp
                                    ? "Already have an account? "
                                    : "Don't have an account? ",
                              ),
                              TextSpan(
                                text: _isSignUp ? "Sign In" : "Sign Up",
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
