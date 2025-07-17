import 'dart:async';
import 'dart:math';
import 'package:iot_data/main.dart';


class SensorDataService {
  final _sensorDataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get sensorDataStream => _sensorDataController.stream;

  Map<String, dynamic> _latestSensorData = { 
    'temperature': 0.0,
    'pressure': 0.0,
    'mq135': 0.0,
    'timestamp': DateTime.now(),
  };
  Map<String, dynamic> get latestSensorData => _latestSensorData; 


  final List<Map<String, dynamic>> _sensorDataHistory = [];
  List<Map<String, dynamic>> get sensorDataHistory => _sensorDataHistory; 
  final int _maxHistorySize = 20; 

  Timer? _timer;
  bool _isAnomalyDetected = false;
  final _anomalyStatusController = StreamController<bool>.broadcast();
  Stream<bool> get anomalyStatusStream => _anomalyStatusController.stream;

  SensorDataService() {
    _startMockSensorDataGeneration();
  }

  void _startMockSensorDataGeneration() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final random = Random();
      // Simulate sensor data
      double temperature = 20.0 + random.nextDouble() * 10; // 20-30 C
      double pressure = 1000.0 + random.nextDouble() * 50; // 1000-1050 hPa
      double mq135 = 50.0 + random.nextDouble() * 100; // 50-150 for air quality

      
      if (random.nextInt(10) < 2) { 
        if (random.nextBool()) { 
          mq135 = 180.0 + random.nextDouble() * 50; 
        } else { 
          temperature = 35.0 + random.nextDouble() * 5; 
        }
      }

      final data = {
        'temperature': temperature,
        'pressure': pressure,
        'mq135': mq135,
        'timestamp': DateTime.now(),
      };
      _latestSensorData = data; 
      _sensorDataController.add(data);

      
      _sensorDataHistory.add(data);
      if (_sensorDataHistory.length > _maxHistorySize) {
        _sensorDataHistory.removeAt(0); 
      }

      _checkAnomaly(data);
    });
  }

  void _checkAnomaly(Map<String, dynamic> data) {
    bool currentAnomalyState = false;
    
    if (data['mq135'] > 170) { 
      currentAnomalyState = true;
    }
    if (data['temperature'] > 33) { 
      currentAnomalyState = true;
    }

    if (currentAnomalyState != _isAnomalyDetected) {
      _isAnomalyDetected = currentAnomalyState;
      _anomalyStatusController.add(_isAnomalyDetected);
      if (_isAnomalyDetected) {
        print('Sensor-only anomaly detected! Buzzer would buzz on IoT kit. Publishing to MQTT...');
        
        mqttService.publishBuzzerCommand('ON');
      } else {
        print('Sensor-only anomaly cleared. Publishing to MQTT...');
        mqttService.publishBuzzerCommand('OFF');
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _sensorDataController.close();
    _anomalyStatusController.close();
  }
}
