import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:iot_data/main.dart';
import 'package:http/http.dart' as http;

class LlmChatScreen extends StatefulWidget {
  const LlmChatScreen({super.key});

  @override
  State<LlmChatScreen> createState() => _LlmChatScreenState();
}

class _LlmChatScreenState extends State<LlmChatScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      "role": "ai",
      "text": "Hello! I'm your Asthma & COPD Assistant. How can I help you today regarding your condition?"
    });
  }

  Future<void> _askLlm() async {
    final userQuestion = _questionController.text.trim();
    if (userQuestion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your question.')),
      );
      return;
    }


    setState(() {
      _messages.add({"role": "user", "text": userQuestion});
      _isLoading = true;
    });
    _questionController.clear();

    final currentSensorData = sensorDataService.latestSensorData;
    final double temp = currentSensorData['temperature'];
    final double press = currentSensorData['pressure'];
    final double mq135 = currentSensorData['mq135'];


    final String llmPrompt = """
    You are an AI assistant specialized in providing information and guidance related to asthma and COPD.
    The user is asking a question about their condition. Please consider the following recent sensor data:
    - Temperature: ${temp.toStringAsFixed(2)} °C
    - Pressure: ${press.toStringAsFixed(2)} hPa
    - Air Quality (MQ135): ${mq135.toStringAsFixed(2)} ppm

    Based on the user's question and this sensor data, provide a helpful and concise response.
    If the sensor data indicates a potential issue (e.g., high MQ135 or unusual temperature), briefly mention it.
    If the question implies a severe or emergency situation, advise seeking immediate medical attention.
    Keep responses relatively short and direct.

    User's Question: "$userQuestion"
    """;

    const apiKey = "AIzaSyBbVMTxPHq_fjBDFnJN08WZCqSe-aGOEiY"; // <<<<<<< REPLACE THIS WITH YOUR ACTUAL GEMINI API KEY >>>>>>>
    const apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey";

    final List<Map<String, dynamic>> geminiChatHistory = [
      {
        "role": "user",
        "parts": [
          {"text": llmPrompt} // Send the detailed prompt to Gemini
        ]
      }
    ];

    final Map<String, dynamic> payload = {
      "contents": geminiChatHistory,
      "generationConfig": {
        "temperature": 0.7, // Adjust creativity (0.0 to 1.0)
        "maxOutputTokens": 150, // Limit response length for brevity and OLED compatibility
      }
    };

    String responseText = "An error occurred. Please try again."; // Initialize with a default value
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['candidates'] != null && result['candidates'].isNotEmpty &&
            result['candidates'][0]['content'] != null &&
            result['candidates'][0]['content']['parts'] != null &&
            result['candidates'][0]['content']['parts'].isNotEmpty) {
          responseText = result['candidates'][0]['content']['parts'][0]['text'];

          // Simple keyword-based anomaly detection from LLM's response
          if (responseText.toLowerCase().contains('seek immediate medical attention') ||
              responseText.toLowerCase().contains('critical') ||
              responseText.toLowerCase().contains('emergency') ||
              responseText.toLowerCase().contains('worsening')) {
            mqttService.publishBuzzerCommand('ON'); // Trigger buzzer for serious alerts
          } else {
            mqttService.publishBuzzerCommand('OFF'); // Ensure buzzer is off for normal responses
          }

        } else {
          responseText = "AI: I couldn't generate a coherent response. Please try rephrasing.";
          mqttService.publishBuzzerCommand('OFF');
        }
      } else {
        responseText = "AI: API error (${response.statusCode}). Please check connection/key.";
        print("Gemini API Error: ${response.statusCode} - ${response.body}");
        mqttService.publishBuzzerCommand('OFF');
      }
    } catch (e) {
      responseText = "AI: Network error ($e). Please check your internet connection.";
      print('Error calling Gemini API: $e');
      mqttService.publishBuzzerCommand('OFF');
    } finally {
      setState(() {
        _messages.add({"role": "ai", "text": responseText});
        _isLoading = false;
      });

      final String oledMessage = responseText.length > 50 ? '${responseText.substring(0, 47)}...' : responseText;
      mqttService.publishOledMessage(oledMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with an assistant'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueGrey.shade100 : Colors.blueGrey.shade500,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isUser ? 15 : 0),
                        topRight: Radius.circular(isUser ? 0 : 15),
                        bottomLeft: const Radius.circular(15),
                        bottomRight: const Radius.circular(15),
                      ),
                    ),
                    child: Text(
                      message["text"]!,
                      style: TextStyle(
                        color: isUser ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'Ask your question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (value) => _askLlm(),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _isLoading ? null : _askLlm,
                  mini: true,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Disclaimer: This LLM is for informational purposes only and does not provide medical advice. Consult a healthcare professional for diagnosis and treatment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
