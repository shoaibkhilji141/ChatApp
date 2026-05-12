import 'package:flutter/material.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/otp_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/home/home_page.dart';
import '../../features/profile/profile_page.dart';

class AppRoutes {
  static const String login = '/';
  static const String signup = '/signup';
  static const String otp = '/otp';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String chat = '/chat';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupPage());
      case otp:
        final args = settings.arguments as OtpPageArguments?;
        return MaterialPageRoute(builder: (_) => OtpPage(arguments: args));
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case chat:
        final args = settings.arguments as Map<String, dynamic>?;
        final contactId = (args?['contactId'] ?? '') as String;
        final contactName = (args?['contactName'] ?? 'Contact Name') as String;
        final isGroup = (args?['isGroup'] ?? false) as bool;
        return MaterialPageRoute(
          builder: (_) => ChatPage(
            contactId: contactId,
            contactName: contactName,
            isGroup: isGroup,
          ),
        );
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
