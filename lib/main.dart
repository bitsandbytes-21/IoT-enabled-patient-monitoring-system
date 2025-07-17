import 'package:flutter/material.dart';
import 'package:iot_data/screens/AuthScreen.dart';
import 'package:iot_data/screens/DailyReportDcreen.dart';
import 'package:iot_data/screens/DashboardScreen.dart';
import 'package:iot_data/screens/LLMScreen.dart';
import 'package:iot_data/screens/RegistrationScreen.dart';
import 'package:iot_data/services/MqttService.dart';
import 'package:iot_data/services/SensorDataService.dart';

final SensorDataService sensorDataService = SensorDataService();
final MqttService mqttService = MqttService();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asthma & COPD Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/daily_report': (context) => const DailyReportScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/llm_chat': (context) => const LlmChatScreen(),
      },
    );
  }
}
