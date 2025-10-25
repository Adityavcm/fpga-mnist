# train_mnist_mlp.py
import numpy as np
from tensorflow import keras

# 1. load MNIST
(x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()
x_train = x_train.reshape(-1, 784).astype('float32') / 255.0
x_test  = x_test.reshape(-1, 784).astype('float32') / 255.0

# 2. model: 784 -> 64 -> 10
model = keras.Sequential([
    keras.layers.Input(shape=(784,)),
    keras.layers.Dense(64, activation='relu', name='fc0'),
    keras.layers.Dense(10, name='fc1')  # logits; we'll take argmax on FPGA
])

model.compile(optimizer='adam',
              loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
              metrics=['accuracy'])

model.fit(x_train, y_train, epochs=25, batch_size=128, validation_split=0.1)
print("Test eval:")
print(model.evaluate(x_test, y_test))

model.save('mlp_mnist.h5')

