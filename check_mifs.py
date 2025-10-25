# check_mifs_fixed.py
import json, re, os
import numpy as np

meta_path = 'mif_weights/weights_meta.json'
if not os.path.exists(meta_path):
    print("weights_meta.json not found in mif_weights/")
    raise SystemExit(1)

meta = json.load(open(meta_path))
print("Layers in meta:", list(meta.keys()))

def read_mif(path):
    vals = []
    with open(path, 'r') as f:
        for line in f:
            m = re.match(r'\s*(\d+)\s*:\s*([0-9A-Fa-f]+)\s*;', line)
            if m:
                hexstr = m.group(2)
                u = int(hexstr, 16)
                vals.append(u)
    return vals

for name, info in meta.items():
    print(f"\nLayer: {name}")
    r, c = info['W_shape']
    print("  W_shape:", info['W_shape'], " b_shape:", info['b_shape'])
    scale = float(info['scale'])
    print("  scale:", scale)
    Wmif = os.path.join('mif_weights', info['W_mif'])
    bmif = os.path.join('mif_weights', info['b_mif'])

    Wvals = read_mif(Wmif)
    Bvals = read_mif(bmif)

    # sanity lengths
    expectedW = r * c
    actualW = len(Wvals)
    actualb = len(Bvals)
    print("  expected W entries:", expectedW, " actual:", actualW, " b expected:", info['b_shape'][0], " actual:", actualb)

    # helper to convert uint16 -> int16 signed
    def u16_to_i16(u):
        # safe: wrap into numpy uint16 then view as int16
        return np.int16(np.uint16(u)).item()

    sampleN = min(8, actualW)
    sampW_u = Wvals[:sampleN]
    sampW_i = [u16_to_i16(x) for x in sampW_u]
    sampW_f = [float(x)/scale for x in sampW_i]

    sampB_u = Bvals[:min(8, actualb)]
    sampB_i = [u16_to_i16(x) for x in sampB_u]
    sampB_f = [float(x)/scale for x in sampB_i]

    print("  first %d raw uint16 W:" % sampleN, sampW_u)
    print("  first %d as signed int16 W:" % sampleN, sampW_i)
    print("  first %d dequantized float W (signed/scale):" % sampleN, sampW_f)
    print("  first %d raw uint16 b:" % len(sampB_u), sampB_u)
    print("  first %d as signed int16 b:" % len(sampB_u), sampB_i)
    print("  first %d dequantized float b:" % len(sampB_u), sampB_f)

    # quick max/min check
    W_signed = np.array([u16_to_i16(x) for x in Wvals], dtype=np.int32)
    b_signed = np.array([u16_to_i16(x) for x in Bvals], dtype=np.int32)
    print("  W signed range:", int(W_signed.min()), int(W_signed.max()))
    print("  b signed range:", int(b_signed.min()), int(b_signed.max()))
    print("  W dequantized range:", float(W_signed.min())/scale, float(W_signed.max())/scale)
    print("  b dequantized range:", float(b_signed.min())/scale, float(b_signed.max())/scale)

