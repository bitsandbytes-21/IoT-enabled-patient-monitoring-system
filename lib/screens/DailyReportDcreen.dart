import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:iot_data/main.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _runnyNosePresent = false;
  double _runnyNoseSeverity = 1.0;
  bool _nasalCongestionPresent = false;
  double _nasalCongestionSeverity = 1.0;
  bool _difficultyBreathingPresent = false;
  double _difficultyBreathingSeverity = 1.0;
  bool _dryCoughPresent = false;
  double _dryCoughSeverity = 1.0;
  bool _tirednessPresent = false;
  double _tirednessSeverity = 1.0;

  String _llmReportResult = '';
  bool _isLoading = false;

  Future<String> _getLlmResponse(String promptText) async {
    const apiKey = "YOUR_GEMINI_API_KEY";
    const apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey";

    final List<Map<String, dynamic>> chatHistory = [
      {
        "role": "user",
        "parts": [
          {"text": "As an asthma/COPD assistant, analyze this health report and sensor data. Provide a concise daily health report (max 200 characters) and indicate critical concerns with 'CRITICAL ALERT'.:\n\n$promptText"}
        ]
      }
    ];

    final Map<String, dynamic> payload = {
      "contents": chatHistory,
      "generationConfig": {
        "temperature": 0.7,
        "maxOutputTokens": 200,
      }
    };

    String generatedReport;
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
          generatedReport = result['candidates'][0]['content']['parts'][0]['text'];

          // Anomaly detection based on LLM's response keywords
          if (generatedReport.toLowerCase().contains('critical alert') ||
              generatedReport.toLowerCase().contains('severe') ||
              generatedReport.toLowerCase().contains('emergency')) {
            mqttService.publishBuzzerCommand('ON');
          } else {
            mqttService.publishBuzzerCommand('OFF');
          }

        } else {
          generatedReport = "LLM couldn't generate a coherent response. Please try again.";
          mqttService.publishBuzzerCommand('OFF');
        }
      } else {
        generatedReport = "LLM API error: ${response.statusCode}. Please check your API key and network.";
        print("LLM API Error: ${response.statusCode} - ${response.body}");
        mqttService.publishBuzzerCommand('OFF');
      }
    } catch (e) {
      generatedReport = "Network or LLM error: $e. Please check your internet connection.";
      print('Error calling LLM: $e');
      mqttService.publishBuzzerCommand('OFF');
    }
    return generatedReport;
  }


  void _submitReport() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final int age = int.tryParse(_ageController.text) ?? 0;
      final String runnyNose = _runnyNosePresent ? 'Severity: ${_runnyNoseSeverity.toInt()}' : 'Not present';
      final String nasalCongestion = _nasalCongestionPresent ? 'Severity: ${_nasalCongestionSeverity.toInt()}' : 'Not present';
      final String difficultyBreathing = _difficultyBreathingPresent ? 'Severity: ${_difficultyBreathingSeverity.toInt()}' : 'Not present';
      final String dryCough = _dryCoughPresent ? 'Severity: ${_dryCoughSeverity.toInt()}' : 'Not present';
      final String tiredness = _tirednessPresent ? 'Severity: ${_tirednessSeverity.toInt()}' : 'Not present';
      final String notes = _notesController.text.trim();

      // Get latest sensor data
      final currentSensorData = sensorDataService.latestSensorData;
      final double temp = currentSensorData['temperature'];
      final double press = currentSensorData['pressure'];
      final double mq135 = currentSensorData['mq135'];

      final String llmPrompt = """
      Patient Age: $age
      Symptoms Reported:
      - Runny Nose: $runnyNose
      - Nasal Congestion: $nasalCongestion
      - Difficulty in Breathing: $difficultyBreathing
      - Dry Cough: $dryCough
      - Tiredness: $tiredness
      Additional Notes: ${notes.isEmpty ? 'None' : notes}

      Recent Sensor Data:
      - Temperature: ${temp.toStringAsFixed(2)} °C
      - Pressure: ${press.toStringAsFixed(2)} hPa
      - Air Quality (MQ135): ${mq135.toStringAsFixed(2)} ppm
      """;

      setState(() {
        _isLoading = true;
        _llmReportResult = 'Generating comprehensive report...';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating daily health report with LLM...'),
          duration: Duration(seconds: 4),
        ),
      );


      final String generatedReport = await _getLlmResponse(llmPrompt);
      print('Full LLM Generated Report: $generatedReport');

      setState(() {
        _llmReportResult = generatedReport;
        _isLoading = false;
      });

      final String oledMessage = generatedReport.length > 50 ? '${generatedReport.substring(0, 47)}...' : generatedReport;
      mqttService.publishOledMessage(oledMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report generated. OLED updated: "$oledMessage"'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }


  Widget _buildSymptomToggleAndSlider({
    required String title,
    required bool isPresent,
    required double severity,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onSliderChanged,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              value: isPresent,
              onChanged: onToggle,
            ),
            if (isPresent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Severity: ${severity.toInt()}', style: const TextStyle(fontSize: 16)),
                    Slider(
                      value: severity,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: severity.toInt().toString(),
                      onChanged: onSliderChanged,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Health Report'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Monitor your asthma/COPD symptoms daily.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Age:',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: 'Enter your age',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your age';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Symptoms & Severity:',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              _buildSymptomToggleAndSlider(
                title: 'Runny Nose',
                isPresent: _runnyNosePresent,
                severity: _runnyNoseSeverity,
                onToggle: (bool value) {
                  setState(() {
                    _runnyNosePresent = value;
                  });
                },
                onSliderChanged: (double value) {
                  setState(() {
                    _runnyNoseSeverity = value;
                  });
                },
              ),
              _buildSymptomToggleAndSlider(
                title: 'Nasal Congestion',
                isPresent: _nasalCongestionPresent,
                severity: _nasalCongestionSeverity,
                onToggle: (bool value) {
                  setState(() {
                    _nasalCongestionPresent = value;
                  });
                },
                onSliderChanged: (double value) {
                  setState(() {
                    _nasalCongestionSeverity = value;
                  });
                },
              ),
              _buildSymptomToggleAndSlider(
                title: 'Difficulty in Breathing',
                isPresent: _difficultyBreathingPresent,
                severity: _difficultyBreathingSeverity,
                onToggle: (bool value) {
                  setState(() {
                    _difficultyBreathingPresent = value;
                  });
                },
                onSliderChanged: (double value) {
                  setState(() {
                    _difficultyBreathingSeverity = value;
                  });
                },
              ),
              _buildSymptomToggleAndSlider(
                title: 'Dry Cough',
                isPresent: _dryCoughPresent,
                severity: _dryCoughSeverity,
                onToggle: (bool value) {
                  setState(() {
                    _dryCoughPresent = value;
                  });
                },
                onSliderChanged: (double value) {
                  setState(() {
                    _dryCoughSeverity = value;
                  });
                },
              ),
              _buildSymptomToggleAndSlider(
                title: 'Tiredness',
                isPresent: _tirednessPresent,
                severity: _tirednessSeverity,
                onToggle: (bool value) {
                  setState(() {
                    _tirednessPresent = value;
                  });
                },
                onSliderChanged: (double value) {
                  setState(() {
                    _tirednessSeverity = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Notes (optional):',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'e.g., Shortness of breath, wheezing, cough...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Generate Daily Report'),
              ),
              const SizedBox(height: 20),
              if (_llmReportResult.isNotEmpty)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.blueGrey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Generated Report:',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).primaryColorDark),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _llmReportResult,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Disclaimer: This report is generated by AI and is for informational purposes only. Always consult a healthcare professional for diagnosis and treatment.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
