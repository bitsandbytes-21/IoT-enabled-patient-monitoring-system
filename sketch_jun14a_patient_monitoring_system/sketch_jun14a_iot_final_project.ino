#include <WiFi.h>
#include <PubSubClient.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>          
#include <Adafruit_GFX.h>  
#include <Adafruit_SSD1306.h> 


const char* ssid = "Bhowmick";        
const char* password = "MLK69@22gh"; 


const char* mqtt_server = "YOUR_BROKER ADDRESS"; 
const char* mqtt_user = "YOUR_MQTT_USERNAME";       
const char* mqtt_pass = "YOUR_MQTT_PASSWORD";          


WiFiClient espClient;
PubSubClient client(espClient);
Adafruit_BMP280 bmp; 


const int BUZZER_PIN = 27; 
const int MQ135_PIN = 36; 


#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels
#define OLED_RESET -1    // Reset pin # (or -1 if sharing Arduino reset pin)
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);



const char* SENSOR_DATA_TOPIC = "iot/sensor/data";           // For publishing sensor data to Flutter app
const char* BUZZER_CONTROL_TOPIC = "iot/esp/buzzer"; // For receiving buzzer commands from Flutter app
const char* OLED_DISPLAY_TOPIC = "iot/esp/oled";     // For receiving LLM/other messages for OLED from Flutter app


unsigned long lastMsg = 0;
const long interval = 5000; 

void setup_wifi();
void callback(char* topic, byte* payload, unsigned int length);
void reconnect();
float readMQ135();
void controlBuzzer(bool turnOn);
void displayOLEDMessage(const String& message);

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


float readMQ135() {
  int sensorValue = analogRead(MQ135_PIN); 
 
  return map(sensorValue, 0, 4095, 0, 1000); 
}


void controlBuzzer(bool turnOn) {
  if (turnOn) {
    digitalWrite(BUZZER_PIN, HIGH); 
  } else {
    digitalWrite(BUZZER_PIN, LOW);  
  }
}


void displayOLEDMessage(const String& message) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0,0);
  display.println("From App:"); 
  display.setTextSize(1); 
  display.println(); 
  
  
  int line_height = 10; 
  int max_chars_per_line = 21; 
  
  
  String currentLine = "";
  int currentY = 15; 
  for (int i = 0; i < message.length(); ++i) {
    currentLine += message[i];
    if (currentLine.length() >= max_chars_per_line || i == message.length() - 1 || message[i] == '\n') {
      display.setCursor(0, currentY);
      display.println(currentLine);
      currentLine = "";
      currentY += line_height;
      if (currentY >= SCREEN_HEIGHT) break; 
    }
  }
  display.display();
}


void setup() {
  Serial.begin(115200); 
  pinMode(BUZZER_PIN, OUTPUT); 
  digitalWrite(BUZZER_PIN, LOW); 

  
  setup_wifi();

  
  client.setServer(mqtt_server, 1883); 
  client.setCallback(callback);

 
  if (!bmp.begin(0x76)) {
    Serial.println("Could not find BMP sensor! Check wiring. Freezing...");
    while (1); 
  }
  Serial.println("BMP sensor initialized.");

  
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 allocation failed. Check wiring/address. Freezing..."));
    for(;;); 
  }
  Serial.println("OLED display initialized.");
  display.display(); 
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0,0);
  display.println("ESP32 Ready!");
  display.display();
  delay(2000); 
}


void loop() {
  
  if (!client.connected()) {
    reconnect();
  }
  client.loop(); 

  
  unsigned long now = millis();
  if (now - lastMsg > interval) {
    lastMsg = now;

    
    float temperature = bmp.readTemperature();
    float pressure = bmp.readPressure() / 100.0F;
    float air_quality = readMQ135(); 

    Serial.print("Temp: ");
    Serial.print(temperature);
    Serial.print(" °C, Pressure: ");
    Serial.print(pressure);
    Serial.print(" hPa, Air quality: ");
    Serial.print(air_quality);
    Serial.println(" ppm");

    
    String payload = "{\"temperature\":";
    payload += String(temperature, 2); 
    payload += ",\"pressure\":";
    payload += String(pressure, 2);
    payload += ",\"air_quality\":";
    payload += String(air_quality, 2);
    payload += "}";

    
    client.publish(SENSOR_DATA_TOPIC, payload.c_str());
    Serial.print("Published sensor data: ");
    Serial.println(payload);
  }
}
