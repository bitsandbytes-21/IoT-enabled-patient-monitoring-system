import paho.mqtt.client as mqtt
import json
import mysql.connector

conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="1234",
    database="asthma_db",
)
cursor = conn.cursor()

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

# The callback for when the client receives a CONNACK response from the server.
def on_connect(client, userdata, flags, rc, properties=None):
    print("Connected with result code", rc)
    # Subscribing in on_connect() means that if we lose the connection and
    # reconnect then subscriptions will be renewed.
    client.subscribe("iot/sensor/data")
    
# The callback for when a PUBLISH message is received from the server.
def on_message(client, userdata, msg):
    print("Message received:", msg.payload.decode())
    try:
        payload = json.loads(msg.payload.decode())
        temperature = payload.get("temperature")
        pressure = payload.get("pressure")
        air_quality = payload.get("air_quality")
        if temperature is not None and pressure is not None and air_quality is not None:
            cursor.execute("INSERT INTO sensor_readings (temperature, pressure, air_quality) VALUES (%s, %s, %s)", (temperature, pressure, air_quality))
            conn.commit()
            print("Data inserted:", temperature, pressure, air_quality)
        else:
            print("Incomplete payload:", payload)
    except Exception as e:
        print("Error:", e)

# Setup MQTT client
mqttc = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

mqttc.username_pw_set("uryaswi", "1234")
mqttc.on_connect = on_connect
mqttc.on_message = on_message

mqttc.connect("localhost", 1883, 60)

# Blocking call that processes network traffic, dispatches callbacks and
# handles reconnecting.
# Other loop*() functions are available that give a threaded interface and a
# manual interface.
mqttc.loop_forever()
