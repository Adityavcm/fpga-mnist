# host_send_image.py
import serial, time, argparse
from tensorflow import keras
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument('--port', required=True)
parser.add_argument('--baud', type=int, default=115200)
parser.add_argument('--index', type=int, default=0)
args = parser.parse_args()

(_, _), (x_test, y_test) = keras.datasets.mnist.load_data()
img = x_test[args.index]  # uint8 28x28
label = int(y_test[args.index])
data = img.flatten().astype('uint8').tobytes()

ser = serial.Serial(args.port, args.baud, timeout=2)
time.sleep(0.1)
ser.write(bytes([0xAA]))
ser.write(data)
# wait for reply
resp = ser.read(1)
if len(resp) == 0:
    print("No response")
else:
    print("Predicted:", resp[0], "True:", label)
ser.close()
