import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:womensafteyhackfair/twilio_config.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to send SMS via Twilio REST API.
/// Works on all platforms (Web, Android, iOS) — no native SMS permissions needed.
class TwilioService {
  static final TwilioService _instance = TwilioService._internal();
  factory TwilioService() => _instance;
  TwilioService._internal();

  /// Sends an SMS to [toNumber] with [messageBody] via native Telephony (on Android) or falls back to Twilio.
  /// Returns true if the message was sent or queued successfully.
  Future<bool> sendSMS({
    required String toNumber,
    required String messageBody,
  }) async {
    // Ensure number has country code
    String formattedNumber = _formatPhoneNumber(toNumber);

    // Try native SMS first on Android if permission is granted
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final smsStatus = await Permission.sms.status;
        if (smsStatus.isGranted) {
          debugPrint('Sending native SMS via Telephony to $formattedNumber...');
          final telephony = Telephony.instance;
          await telephony.sendSms(
            to: formattedNumber,
            message: messageBody,
          );
          debugPrint('✅ Native SMS sent successfully via Telephony');
          return true;
        } else {
          debugPrint('SMS Permission not granted. Falling back to Twilio.');
        }
      } catch (e) {
        debugPrint('❌ Native SMS failed: $e. Falling back to Twilio.');
      }
    }

    debugPrint('Using Twilio SID: ${TwilioConfig.accountSid}');
    debugPrint('Using Twilio Number: ${TwilioConfig.twilioNumber}');

    final url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/${TwilioConfig.accountSid}/Messages.json',
    );

    final credentials = base64Encode(
      utf8.encode('${TwilioConfig.accountSid}:${TwilioConfig.authToken}'),
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': TwilioConfig.twilioNumber,
          'To': formattedNumber,
          'Body': messageBody,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Twilio SMS sent to $formattedNumber');
        debugPrint('Response: ${response.body}');
        return true;
      } else {
        debugPrint('❌ Twilio SMS failed: ${response.statusCode}');
        debugPrint('Error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Twilio SMS exception: $e');
      return false;
    }
  }

  /// Places an emergency voice call to [toNumber] with a spoken [voiceMessage] via Twilio.
  /// Returns true if the call was queued successfully.
  Future<bool> makeVoiceCall({
    required String toNumber,
    required String voiceMessage,
  }) async {
    // Ensure number has country code
    String formattedNumber = _formatPhoneNumber(toNumber);

    debugPrint('Using Twilio SID: ${TwilioConfig.accountSid}');
    debugPrint('Using Twilio Number: ${TwilioConfig.twilioNumber}');

    final url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/${TwilioConfig.accountSid}/Calls.json',
    );

    final credentials = base64Encode(
      utf8.encode('${TwilioConfig.accountSid}:${TwilioConfig.authToken}'),
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': TwilioConfig.twilioNumber,
          'To': formattedNumber,
          'Twiml': '<Response><Say voice="alice">$voiceMessage</Say></Response>',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Twilio Voice Call placed to $formattedNumber');
        debugPrint('Response: ${response.body}');
        return true;
      } else {
        debugPrint('❌ Twilio Voice Call failed: ${response.statusCode}');
        debugPrint('Error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Twilio Voice Call exception: $e');
      return false;
    }
  }

  /// Formats phone number to E.164 format.
  /// Handles Indian numbers (10-digit → +91...) and others.
  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters except leading +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // If it already starts with +, assume it's formatted
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // Remove leading zeros
    cleaned = cleaned.replaceAll(RegExp(r'^0+'), '');

    // Indian 10-digit number
    if (cleaned.length == 10) {
      return '+91$cleaned';
    }

    // Already has country code (e.g., 91XXXXXXXXXX)
    if (cleaned.length > 10) {
      return '+$cleaned';
    }

    // Fallback: add + prefix
    return '+$cleaned';
  }
}
