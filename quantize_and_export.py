# quantize_and_export.py
import numpy as np
import json
import os
from tensorflow import keras

def ensure_dir(d):
    if not os.path.exists(d):
        os.makedirs(d)

model = keras.models.load_model('mlp_mnist.h5')
layers = []
for layer in model.layers:
    if hasattr(layer, 'get_weights'):
        wb = layer.get_weights()
        if len(wb) == 2:
            W, b = wb
            layers.append((layer.name, W.astype(np.float32), b.astype(np.float32)))

outdir = 'mif_weights'
ensure_dir(outdir)
meta = {}

def write_mif(path, arr_flat):
    depth = arr_flat.size
    with open(path, 'w') as f:
        f.write("DEPTH = %d;\n" % depth)
        f.write("WIDTH = 16;\n")
        f.write("ADDRESS_RADIX = DEC;\n")
        f.write("DATA_RADIX = HEX;\n")
        f.write("CONTENT\nBEGIN\n")
        for addr, val in enumerate(arr_flat):
            u = np.uint16(val).item()
            f.write("  %d : %04X;\n" % (addr, u))
        f.write("END;\n")

for idx, (name, W, b) in enumerate(layers):
    # choose one scale per layer for both weights and bias
    max_abs = max(np.max(np.abs(W)), np.max(np.abs(b)))
    if max_abs == 0:
        scale = 1.0
    else:
        scale = 32767.0 / float(max_abs)
    # quantize
    Wq = np.round(W * scale).astype(np.int16)
    bq = np.round(b * scale).astype(np.int16)

    # shapes
    r, c = W.shape  # r = input_dim, c = out_dim
    meta[name] = {
        'layer_index': idx,
        'W_shape': [int(r), int(c)],
        'b_shape': [int(bq.shape[0])],
        'scale': float(scale),
        'W_mif': f'{name}_W.mif',
        'b_mif': f'{name}_b.mif',
        'addr_mapping': 'row_major: addr = i * H + j (i=0..r-1, j=0..c-1)'
    }

    # flatten row-major (i*H + j)
    W_flat = Wq.flatten(order='C')  # row-major
    b_flat = bq.flatten(order='C')

    write_mif(os.path.join(outdir, f'{name}_W.mif'), W_flat)
    write_mif(os.path.join(outdir, f'{name}_b.mif'), b_flat)

# write meta
with open(os.path.join(outdir, 'weights_meta.json'), 'w') as f:
    json.dump(meta, f, indent=2)

print("Wrote MIFs and weights_meta.json to:", outdir)
print("IMPORTANT: The scale in weights_meta.json is the per-layer multiplier used to convert float->int16.")
print("In the FPGA we assume inputs & weights are Q1.15; products are accumulated into 64-bit and >>15 to rescale.")

