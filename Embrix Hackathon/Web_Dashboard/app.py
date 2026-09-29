from flask import Flask, render_template
from flask_socketio import SocketIO
import paho.mqtt.client as mqtt
import json
import threading

app = Flask(__name__)
app.config['SECRET_KEY'] = 'veda_hackathon_secret'
socketio = SocketIO(app, cors_allowed_origins="*")

MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_TOPIC_TELEMETRY = "veda/telemetry"
MQTT_TOPIC_ALERTS = "veda/alerts"
MQTT_TOPIC_VIDEO = "veda/video"

def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] Connected with result code {rc}")
    client.subscribe([(MQTT_TOPIC_TELEMETRY, 0), (MQTT_TOPIC_ALERTS, 0), (MQTT_TOPIC_VIDEO, 0)])

def on_message(client, userdata, msg):
    topic = msg.topic
    if topic == MQTT_TOPIC_VIDEO:
        socketio.emit('video_frame', msg.payload.decode('utf-8'))
        return
        
    payload = msg.payload.decode('utf-8')
    try:
        data = json.loads(payload)
        if topic == MQTT_TOPIC_TELEMETRY:
            socketio.emit('telemetry_update', data)
        elif topic == MQTT_TOPIC_ALERTS:
            socketio.emit('alert_trigger', data)
    except json.JSONDecodeError:
        pass

def mqtt_thread():
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_forever()
    except Exception as e:
        print("[MQTT] Error: Mosquitto broker is not running!")

@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    threading.Thread(target=mqtt_thread, daemon=True).start()
    socketio.run(app, host='0.0.0.0', port=5000, debug=True, use_reloader=False)
