import paho.mqtt.client as mqtt
import json
import mysql.connector
from datetime import datetime

# --- Connect to MySQL Database ---
conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="1234",
    database="asthma_db"
)
cursor = conn.cursor()

# --- Create Table if Not Exists ---
cursor.execute("""
CREATE TABLE IF NOT EXISTS sensor_readings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    temperature FLOAT,
    pressure FLOAT,
    air_quality FLOAT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
)
""")
conn.commit()

# --- MQTT Callbacks ---
def on_connect(client, userdata, flags, rc):
    print("Connected to MQTT broker with code:", rc)
    client.subscribe("iot/sensor/data")

def on_message(client, userdata, msg):
    print("Received message on topic:", msg.topic)
    try:
        data = json.loads(msg.payload.decode())
        temperature = data.get("temperature")
        pressure = data.get("pressure")
        air_quality = data.get("air_quality")

        print(f"Parsed -> Temp: {temperature}, Pressure: {pressure}, AQI: {air_quality}")

        if temperature is not None and pressure is not None and air_quality is not None:
            cursor.execute("""
                INSERT INTO sensor_readings (temperature, pressure, air_quality)
                VALUES (%s, %s, %s)
            """, (temperature, pressure, air_quality))
            conn.commit()
            print("Data inserted:", temperature, pressure, air_quality)
        else:
            print("Incomplete data:", data)

    except Exception as e:
        print("Error processing message:", e)

# --- MQTT Client Setup ---
mqtt_client = mqtt.Client()
mqtt_client.username_pw_set("uryaswi", "1234")
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message

mqtt_client.connect("localhost", 1883, 60)

# --- Start Loop ---
mqtt_client.loop_forever()
