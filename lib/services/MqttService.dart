import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? client;
  String _broker = '192.168.29.100';
  final int _port = 1883;
  String _clientId = 'flutter_client_${Random().nextInt(1000)}';
  String? _username = 'uryaswi';
  String? _password = '1234';

  // Topics
  final String _sensorDataTopic = 'iot/sensor/data';
  final String _buzzerControlTopic = 'iot/esp/buzzer';
  final String _oledDisplayTopic = 'iot/esp/oled';

  void initialize(String username, String password, {String broker = '192.168.29.100', int port = 1883}) {
    _username = username;
    _password = password;
    _broker = broker;
    _clientId = 'flutter_client_${Random().nextInt(1000)}'; // Generate a new client ID for each session
  }

  Future<void> connect() async {
    if (client != null && client!.connectionStatus?.state == MqttConnectionState.connected) {
      print('MQTT client already connected.');
      return;
    }

    client = MqttServerClient(_broker, _clientId);
    client?.port = _port;
    client?.logging(on: false); // Set to true for debugging
    client?.keepAlivePeriod = 20;
    client?.onConnected = _onConnected;
    client?.onDisconnected = _onDisconnected;
    client?.onUnsubscribed = _onUnsubscribed;
    client?.onSubscribed = _onSubscribed;
    client?.onSubscribeFail = _onSubscribeFail;


    MqttConnectMessage connMess = MqttConnectMessage().withClientIdentifier(_clientId);


    if (_username != null && _password != null) {
      connMess = connMess.authenticateAs(_username!, _password!);
    }


    connMess = connMess
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client?.connectionMessage = connMess;

    try {
      print('Attempting to connect to Mosquitto MQTT broker: $_broker with client ID: $_clientId');
      await client?.connect();
    } catch (e) {
      print('MQTT client exception - $e');
      client?.disconnect();
    }

    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      print('MQTT client connected successfully to Mosquitto!');
      _subscribeToSensorData();
    } else {
      print('MQTT client connection failed - status: ${client?.connectionStatus}');
    }
  }

  void _onConnected() {
    print('MQTT: Connected');
  }

  void _onDisconnected() {
    print('MQTT: Disconnected');

  }

  void _onSubscribed(String topic) {
    print('MQTT: Subscribed to $topic');
  }

  void _onSubscribeFail(String topic) {
    print('MQTT: Failed to subscribe to $topic');
  }

  void _onUnsubscribed(String? topic) {
    print('MQTT: Unsubscribed from $topic');
  }

  void _subscribeToSensorData() {

    client?.subscribe(_sensorDataTopic, MqttQos.atLeastOnce);
    client?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('MQTT: Received data on topic: ${c[0].topic}, payload: $payload');
      try {
        final Map<String, dynamic> sensorData = jsonDecode(payload);
         
      } catch (e) {
        print('Error parsing sensor data: $e');
      }
    });
  }

  void publishBuzzerCommand(String command) {
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(command);
      client?.publishMessage(_buzzerControlTopic, MqttQos.atLeastOnce, builder.payload!);
      print('MQTT: Published buzzer command to $_buzzerControlTopic: $command');
    } else {
      print('MQTT: Not connected, cannot publish buzzer command.');
    }
  }

  void publishOledMessage(String message) {
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      client?.publishMessage(_oledDisplayTopic, MqttQos.atLeastOnce, builder.payload!);
      print('MQTT: Published OLED message to $_oledDisplayTopic: $message');
    } else {
      print('MQTT: Not connected, cannot publish OLED message.');
    }
  }

  void disconnect() {
    print('MQTT: Disconnecting client...');
    client?.disconnect();
  }
}