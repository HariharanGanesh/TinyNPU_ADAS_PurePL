import paho.mqtt.client as mqtt
import time
import json
import random

MQTT_BROKER = "localhost"
MQTT_PORT = 1883

def main():
    client = mqtt.Client()
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        print("[MOCK] Connected to MQTT Broker. Simulating VEGA board telemetry...")
    except:
        print("[-] Could not connect to MQTT Broker. Is mosquitto running?")
        return

    mode = "DEFENCE"
    
    while True:
        # Simulate Telemetry
        telemetry = {
            "mode": mode,
            "threat_class": random.choice(["NONE", "NONE", "NONE", "HUMAN"]),
            "iff_status": "WAITING",
            "gas_voc": random.randint(10, 50),
            "seismic_amp": random.randint(5, 25),
            "seismic_trigger": False
        }
        
        # Add some noise/spikes to the chart
        if random.random() > 0.9:
            telemetry["seismic_amp"] = random.randint(80, 100)
            telemetry["seismic_trigger"] = True
            
        client.publish("veda/telemetry", json.dumps(telemetry))
        
        # Simulate Alerts
        if telemetry["threat_class"] == "HUMAN":
            alert = {
                "type": "THREAT_HUMAN",
                "message": "Unidentified human detected at perimeter."
            }
            client.publish("veda/alerts", json.dumps(alert))
            
        time.sleep(1)

if __name__ == '__main__':
    main()
