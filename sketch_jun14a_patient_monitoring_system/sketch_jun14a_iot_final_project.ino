#include <WiFi.h>
#include <PubSubClient.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>          
#include <Adafruit_GFX.h>  
#include <Adafruit_SSD1306.h> 

// --- WiFi Credentials ---
const char* ssid = "Bhowmick";        
const char* password = "MLK69@22gh"; 

// --- MQTT Broker Details (Your Mosquitto Broker) ---
const char* mqtt_server = "192.168.29.100"; 
const char* mqtt_user = "uryaswi";       
const char* mqtt_pass = "1234";          

// --- MQTT Client and Sensor Objects ---
WiFiClient espClient;
PubSubClient client(espClient);
Adafruit_BMP280 bmp; // BMP280 sensor object

// --- Hardware Pin Definitions ---
const int BUZZER_PIN = 27; 
const int MQ135_PIN = 36; 

// --- OLED Display Setup ---
#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels
#define OLED_RESET -1    // Reset pin # (or -1 if sharing Arduino reset pin)
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);


// --- MQTT Topics (Must match topics in Flutter app) ---
const char* SENSOR_DATA_TOPIC = "iot/sensor/data";           // For publishing sensor data to Flutter app
const char* BUZZER_CONTROL_TOPIC = "iot/esp/buzzer"; // For receiving buzzer commands from Flutter app
const char* OLED_DISPLAY_TOPIC = "iot/esp/oled";     // For receiving LLM/other messages for OLED from Flutter app

// --- Timing Variables ---
unsigned long lastMsg = 0;
const long interval = 5000; // Publish sensor data every 5 seconds (5000 ms)

// --- Function Prototypes ---
void setup_wifi();
void callback(char* topic, byte* payload, unsigned int length);
void reconnect();
float readMQ135();
void controlBuzzer(bool turnOn);
void displayOLEDMessage(const String& message);

// --- Setup WiFi Connection ---
void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

// --- MQTT Callback Function (Handles incoming messages from subscribed topics) ---
void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("]: ");
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);

  // Handle buzzer control commands from Flutter app
  if (String(topic) == BUZZER_CONTROL_TOPIC) {
    if (message == "ON") {
      controlBuzzer(true);
      displayOLEDMessage("Buzzer: ON"); // Update OLED with buzzer status
      Serial.println("Buzzer command: ON");
    } else if (message == "OFF") {
      controlBuzzer(false);
      displayOLEDMessage("Buzzer: OFF"); // Update OLED with buzzer status
      Serial.println("Buzzer command: OFF");
    }
  }
  // Handle OLED display messages (LLM responses or other text) from Flutter app
  else if (String(topic) == OLED_DISPLAY_TOPIC) {
    displayOLEDMessage(message);
    Serial.print("OLED message: ");
    Serial.println(message);
  }
}

// --- Reconnect to MQTT Broker ---
void reconnect() {
  // Loop until we're reconnected
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    // Attempt to connect with client ID, username, and password
    if (client.connect("ESP32Client", mqtt_user, mqtt_pass)) {
      Serial.println("connected");
      // Once connected, resubscribe to control topics
      client.subscribe(BUZZER_CONTROL_TOPIC);
      client.subscribe(OLED_DISPLAY_TOPIC);
      Serial.print("Subscribed to ");
      Serial.println(BUZZER_CONTROL_TOPIC);
      Serial.print("Subscribed to "); 
      Serial.println(OLED_DISPLAY_TOPIC);
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" trying again in 5 seconds");
      // Wait 5 seconds before retrying
      delay(5000);
    }
  }
}

// --- Read MQ135 Sensor Data (Analog Reading) ---
// This is a basic analog read. For more accurate ppm values for air quality,
// you might need to use an MQ135 specific library and perform calibration
// according to its datasheet, as raw analog values are not directly ppm.
float readMQ135() {
  int sensorValue = analogRead(MQ135_PIN); // Read the analog value (0-4095 for ESP32)
  // Map analog value to a representative float range (e.g., 0-1000 for demonstration)
  // Adjust this mapping or use a specific MQ135 library for real air quality data.
  return map(sensorValue, 0, 4095, 0, 1000); 
}

// --- Control Buzzer ---
void controlBuzzer(bool turnOn) {
  if (turnOn) {
    digitalWrite(BUZZER_PIN, HIGH); // Turn buzzer ON
  } else {
    digitalWrite(BUZZER_PIN, LOW);  // Turn buzzer OFF
  }
}

// --- Display Message on OLED ---
void displayOLEDMessage(const String& message) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0,0);
  display.println("From App:"); // Small header for context
  display.setTextSize(1); // Set to 1 to fit more text on 128x64
  display.println(); // New line
  
  // Split message to fit on screen if too long (simple word wrap)
  int line_height = 10; // Approximate height for text size 1
  int max_chars_per_line = 21; // Estimate for 128-pixel width, size 1 font
  
  // Manually break lines
  String currentLine = "";
  int currentY = 15; // Starting Y position after "From App:"
  for (int i = 0; i < message.length(); ++i) {
    currentLine += message[i];
    if (currentLine.length() >= max_chars_per_line || i == message.length() - 1 || message[i] == '\n') {
      display.setCursor(0, currentY);
      display.println(currentLine);
      currentLine = "";
      currentY += line_height;
      if (currentY >= SCREEN_HEIGHT) break; // Stop if screen is full
    }
  }
  display.display();
}

// --- Arduino Setup Function (Runs once on startup) ---
void setup() {
  Serial.begin(115200); // Initialize serial communication for debugging
  pinMode(BUZZER_PIN, OUTPUT); // Set buzzer pin as output
  digitalWrite(BUZZER_PIN, LOW); // Ensure buzzer is off initially

  // Initialize WiFi
  setup_wifi();

  // Set MQTT server and callback function for incoming messages
  client.setServer(mqtt_server, 1883); // Standard MQTT port
  client.setCallback(callback);

  // Initialize BMP280 sensor (Temperature/Pressure)
  // Default I2C address for BMP280 is 0x76. If yours is 0x77, use bmp.begin(0x77).
  if (!bmp.begin(0x76)) {
    Serial.println("Could not find BMP sensor! Check wiring. Freezing...");
    while (1); // Halt execution if sensor not found
  }
  Serial.println("BMP sensor initialized.");

  // Initialize OLED display (I2C address 0x3C or 0x3D)
  // Common address for 128x64 OLED is 0x3C. For 128x32, it's often 0x3D.
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 allocation failed. Check wiring/address. Freezing..."));
    for(;;); // Don't proceed, loop forever
  }
  Serial.println("OLED display initialized.");
  display.display(); // Clear display buffer
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0,0);
  display.println("ESP32 Ready!");
  display.display();
  delay(2000); // Show initialization message for a bit
}

// --- Arduino Loop Function (Runs repeatedly) ---
void loop() {
  // Ensure MQTT client is connected. If not, try to reconnect.
  if (!client.connected()) {
    reconnect();
  }
  client.loop(); // Process incoming MQTT messages and maintain connection

  // Publish sensor data periodically
  unsigned long now = millis();
  if (now - lastMsg > interval) {
    lastMsg = now;

    // Read sensor values
    float temperature = bmp.readTemperature();
    float pressure = bmp.readPressure() / 100.0F; // Convert Pa to hPa
    float air_quality = readMQ135(); // Read MQ135 value

    Serial.print("Temp: ");
    Serial.print(temperature);
    Serial.print(" °C, Pressure: ");
    Serial.print(pressure);
    Serial.print(" hPa, Air quality: ");
    Serial.print(air_quality);
    Serial.println(" ppm");

    // Create JSON payload string for the Flutter app
    String payload = "{\"temperature\":";
    payload += String(temperature, 2); // Format to 2 decimal places
    payload += ",\"pressure\":";
    payload += String(pressure, 2);
    payload += ",\"air_quality\":";
    payload += String(air_quality, 2);
    payload += "}";

    // Publish sensor data to the specified topic
    client.publish(SENSOR_DATA_TOPIC, payload.c_str());
    Serial.print("Published sensor data: ");
    Serial.println(payload);
  }
}
