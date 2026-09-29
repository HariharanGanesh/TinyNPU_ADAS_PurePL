import serial
import time
import cv2
import paho.mqtt.client as mqtt
import base64

SERIAL_PORT = 'COM3'
BAUD_RATE = 115200
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_TOPIC_VIDEO = "veda/video"

def main():
    mqtt_client = mqtt.Client()
    try:
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        print("[+] Connected to local MQTT for Video Streaming")
    except:
        print("[-] MQTT Failed.")

    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"[+] Connected to VEGA board on {SERIAL_PORT}")
    except:
        print(f"[-] Could not connect to {SERIAL_PORT}.")
        ser = None

    cap = cv2.VideoCapture('pre_recorded_thermal.mp4')
    if not cap.isOpened():
        print("[-] Could not open pre_recorded_thermal.mp4. Falling back to webcam 0 for testing.")
        cap = cv2.VideoCapture(0)

    print("[+] Starting HIL Video Stream...")
    while True:
        ret, frame = cap.read()
        if not ret:
            cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            continue
            
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        tiny_frame = cv2.resize(gray, (32, 24), interpolation=cv2.INTER_AREA)
        
        if ser:
            ser.write(b'\xAA\x55') 
            ser.write(tiny_frame.tobytes())
            
        display_frame = cv2.resize(tiny_frame, (320, 240), interpolation=cv2.INTER_NEAREST)
        thermal_colored = cv2.applyColorMap(display_frame, cv2.COLORMAP_INFERNO)
        
        _, buffer = cv2.imencode('.jpg', thermal_colored, [cv2.IMWRITE_JPEG_QUALITY, 80])
        jpg_as_text = base64.b64encode(buffer).decode('utf-8')
        mqtt_client.publish(MQTT_TOPIC_VIDEO, jpg_as_text)
        
        cv2.imshow('HIL Simulator Output', thermal_colored)
        time.sleep(0.1)
        
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    if ser: ser.close()

if __name__ == '__main__':
    main()

