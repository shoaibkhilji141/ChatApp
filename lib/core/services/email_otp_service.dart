import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class EmailOtpService {
  EmailOtpService._();

  static final EmailOtpService instance = EmailOtpService._();

  static String get _smtpEmail => dotenv.env['SMTP_EMAIL'] ?? '';

  static String get _smtpAppPassword => dotenv.env['SMTP_APP_PASSWORD'] ?? '';

  String generateOtp({int length = 6}) {
    final random = Random.secure();
    final max = pow(10, length).toInt();
    final min = pow(10, length - 1).toInt();
    return (min + random.nextInt(max - min)).toString();
  }

  Future<void> sendOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    final smtpEmail = _smtpEmail.trim();
    final smtpAppPassword = _smtpAppPassword.trim();

    if (smtpEmail.isEmpty || smtpAppPassword.isEmpty) {
      throw StateError(
        'OTP email is not configured. Update _smtpEmail and '
        '_smtpAppPassword in email_otp_service.dart.',
      );
    }

    final smtpServer = gmail(smtpEmail, smtpAppPassword);
    final message = Message()
      ..from = Address(smtpEmail, 'Chat App')
      ..recipients.add(recipientEmail)
      ..subject = 'Your Chat App OTP Code'
      ..text =
          'Hi $recipientName,\n\n'
          'Your OTP code is: $otpCode\n\n'
          'This code expires in 5 minutes.\n\n'
          'If you did not request this, please ignore this email.';

    try {
      await send(message, smtpServer);
    } on MailerException catch (error) {
      final problem = error.problems.isNotEmpty
          ? error.problems.first.msg
          : error.message;
      throw Exception(
        'Unable to send OTP email. Check SMTP email/app password. Details: '
        '$problem',
      );
    }
  }
}
