import 'package:flutter/material.dart';
import 'package:iot_data/main.dart';
import 'package:fl_chart/fl_chart.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();

    mqttService.connect();
  }

  @override
  void dispose() {

    mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              mqttService.disconnect();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Live Sensor Data',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            StreamBuilder<Map<String, dynamic>>(
              stream: sensorDataService.sensorDataStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData) {
                  return const Text('No sensor data yet.');
                }

                final data = snapshot.data!;
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSensorRow(
                            'Temperature', '${data['temperature']?.toStringAsFixed(2)} °C', Icons.thermostat),
                        _buildSensorRow(
                            'Pressure', '${data['pressure']?.toStringAsFixed(2)} hPa', Icons.compress),
                        _buildSensorRow(
                            'Air Quality (MQ135)', '${data['mq135']?.toStringAsFixed(2)} ppm', Icons.cloud),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Anomaly Status',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            StreamBuilder<bool>(
              stream: sensorDataService.anomalyStatusStream,
              initialData: false,
              builder: (context, snapshot) {
                final isAnomaly = snapshot.data ?? false;
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: isAnomaly ? Colors.red.shade100 : Colors.green.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAnomaly ? Icons.warning : Icons.check_circle,
                          color: isAnomaly ? Colors.red : Colors.green,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isAnomaly ? 'Anomaly Detected! Buzzer Triggered.' : 'All good, no anomalies.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isAnomaly ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Sensor Data Visualization',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),

            StreamBuilder<List<Map<String, dynamic>>>(

              stream: sensorDataService.sensorDataStream.map((_) => sensorDataService.sensorDataHistory),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return SizedBox(
                    height: 250,
                    child: Center(child: Text('Error loading charts: ${snapshot.error}')),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'No sensor data history yet for charts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final List<Map<String, dynamic>> history = snapshot.data!;
                final List<FlSpot> temperatureSpots = [];
                final List<FlSpot> pressureSpots = [];
                final List<FlSpot> mq135Spots = [];


                for (int i = 0; i < history.length; i++) {
                  temperatureSpots.add(FlSpot(i.toDouble(), history[i]['temperature']));
                  pressureSpots.add(FlSpot(i.toDouble(), history[i]['pressure']));
                  mq135Spots.add(FlSpot(i.toDouble(), history[i]['mq135']));
                }

                return Column(
                  children: [
                    _buildChartCard(
                      'Temperature (°C)',
                      temperatureSpots,
                      Colors.orange,
                      minY: 15,
                      maxY: 40,
                    ),
                    const SizedBox(height: 20),
                    _buildChartCard(
                      'Pressure (hPa)',
                      pressureSpots,
                      Colors.blue,
                      minY: 980,
                      maxY: 1070,
                    ),
                    const SizedBox(height: 20),
                    _buildChartCard(
                      'Air Quality (MQ135 ppm)',
                      mq135Spots,
                      Colors.green,
                      minY: 0,
                      maxY: 250,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Daily Health Report & LLM Assistant',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/daily_report');
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('Submit Daily Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/llm_chat'); // Navigate to LLM chat screen
                    },
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('Ask an Assistant'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // const Text(
            //   'Access for family members can be managed through user roles in a backend system.',
            //   style: TextStyle(fontSize: 14, color: Colors.grey),
            //   textAlign: TextAlign.center,
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
      String title, List<FlSpot> spots, Color lineColor,
      {double? minY, double? maxY}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150, // Fixed height for the chart
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10));
                        },
                        reservedSize: 28,
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Corrected: showTitles nested in SideTitles
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Corrected: showTitles nested in SideTitles
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xff37434d), width: 1),
                  ),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(), // X-axis spans the number of data points
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}