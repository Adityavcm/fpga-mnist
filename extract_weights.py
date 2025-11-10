import tensorflow as tf
import numpy as np

# Load the trained model
model = tf.keras.models.load_model('mnist_mlp_model.h5')

# Get the weights and biases of the dense layer
weights_float, biases_float = model.layers[0].get_weights()

# Adjust weights for unnormalized Verilog inputs (multiply by 255)
weights = weights_float * 255.0
biases = biases_float

# --- Quantization to 16-bit signed integers ---

# Find the absolute maximum value in weights and biases to determine the scaling factor
max_val = np.max([np.abs(weights).max(), np.abs(biases).max()])

# Calculate the scaling factor to map the float values to the 16-bit integer range
# We'll use 15 bits for the value and 1 for the sign, so the range is -32768 to 32767
scale_factor = 32767.0 / max_val

# Quantize weights and biases
quantized_weights = (weights * scale_factor).astype(np.int16)
quantized_biases = (biases * scale_factor).astype(np.int16)

# --- Save to .hex files ---

def save_to_hex(data, filename):
    with open(filename, 'w') as f:
        for val in np.nditer(data):
            # Convert numpy scalar to Python int before formatting
            hex_val = format(int(val) & 0xFFFF, '04x')
            f.write(hex_val + '\n')

save_to_hex(quantized_weights, 'weights.hex')
save_to_hex(quantized_biases, 'biases.hex')

print("Weights and biases have been quantized and saved to weights.hex and biases.hex")
print(f"Original floating point range was roughly [{-max_val:.4f}, {max_val:.4f}]")
print(f"This has been mapped to the 16-bit integer range with a scale factor of {scale_factor:.4f}")
