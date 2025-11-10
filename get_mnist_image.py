import tensorflow as tf
import numpy as np

# Load the MNIST dataset
(_, _), (x_test, y_test) = tf.keras.datasets.mnist.load_data()

# --- Select the first image and label from the test set ---
image_index = 5
selected_image = x_test[image_index]
correct_label = y_test[image_index]

print(f"Selected image index {image_index} from the test set.")
print(f"The correct label for this image is: {correct_label}")

# --- Convert and save the image to .hex format ---
# The image is a 28x28 array, we need to flatten it to 784 pixels
flat_image = selected_image.flatten()

output_filename = "image.hex"
with open(output_filename, 'w') as f:
    for pixel_value in flat_image:
        # Format the 8-bit pixel value as a 2-digit hex string
        f.write(f"{pixel_value:02x}\n")

print(f"Image has been converted and saved to {output_filename}")