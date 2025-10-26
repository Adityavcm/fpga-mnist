# FPGA MNIST — MLP digit recognition on DE2-115

> Small, portable implementation of an MNIST digit classifier that is trained on a PC (TensorFlow/Keras), quantized and exported to `.mif` memory files, and run entirely in HDL on an Intel/Altera DE2-115 FPGA. Host ↔ FPGA communication uses a simple UART protocol.

---

## Project summary

This repository contains:
- A minimal MLP (784 → 64 → 10) trained on MNIST with TensorFlow/Keras.
- A quantization & export pipeline that produces 16-bit fixed-point weight/bias `.mif` files for FPGA ROM initialization.
- Verilog modules (UART, MAC, controller, top) that perform inference on the FPGA using on-chip memory (ROM for weights, RAM for input/hidden activations).
- A host script (`host_send_image.py`) to send an MNIST image over USB-UART and receive the predicted digit.

Goal: a reproducible, educational end-to-end flow from training → FPGA deployment.

---

## Features & design notes

- **Model**: MLP, one hidden layer (64 neurons) + output layer (10 logits).
- **Quantization**: per-layer symmetric scaling to signed 16-bit (Q1.15-ish). Export script produces `.mif` files row-major with metadata.
- **Numerics**: weights/biases and activations use 16-bit fixed point. 16×16 multiply → 64-bit accumulator; accumulator >> 15 to scale back.
- **Memory mapping**: weights in ROMs initialized by `.mif` files. Input image and hidden activations stored in on-chip RAM.
- **Host protocol**: host sends one header byte (0xAA) then 784 raw bytes (unsigned 0–255). FPGA replies with one byte (0–9) — predicted digit.
- **Target board**: DE2-115 (Cyclone IV). Uses Quartus Prime for synthesis and programmer to load the arrangement.

---

## Quickstart (tl;dr)

1. Train the model on your laptop:
   ```bash
   python3 train_mnist_mlp.py
produces mlp_mnist.h5.

Quantize & export .mif files:

bash
Copy code
python3 quantize_and_export.py
generates mif_weights/ and weights_meta.json.

Create a Quartus project, add Verilog sources and generated IP (ROM/RAM) with each .mif as initialization.

Compile & program the DE2-115.

Send a test image:

bash
Copy code
python3 host_send_image.py --port /dev/ttyUSB0 --index 0
result: predicted digit printed to console.

Repository layout
graphql
Copy code
fpga-mnist/
├── mif_weights/              # Generated .mif weight + bias files (from quantize_and_export.py)
├── verilog/                  # Verilog sources (uart_rx.v, uart_tx.v, mac_unit.v, top_mnist.v, ...)
├── train_mnist_mlp.py        # Keras training script
├── quantize_and_export.py    # Convert model -> fixed point -> .mif
├── check_mifs.py             # Optional: verify MIF contents & shapes
├── host_send_image.py        # Host client to send MNIST image via serial
├── commands.txt              # Useful commands for Quartus / push / etc.
├── README.md                 # This file
└── .gitignore                # ignore venv, Quartus build, large files
Environment & dependencies
Python (training & export)

Python 3.8–3.11 recommended.

```markdown
### Install dependencies from `requirements.txt`

# (1) If you're using a virtual environment, activate it first:
# Linux / macOS
source lenet-env/bin/activate
# Windows (PowerShell)
lenet-env\Scripts\activate

# (2) Install everything from the file:
pip install -r requirements.txt

# (3) If you see "externally-managed-environment" — create & use a venv, then run the install:
python3 -m venv lenet-env
source lenet-env/bin/activate
pip install -r requirements.txt
```


FPGA toolchain

Intel Quartus Prime (the Lite or Standard edition that matches DE2-115).

Optionally ModelSim for simulation.

Training (local)
train_mnist_mlp.py trains the MLP and saves a Keras model file:

bash
Copy code
python3 train_mnist_mlp.py
# -> mlp_mnist.h5
Notes:

You can change epochs, hidden size in the script.

If training is slow, reduce epochs or hidden units.

Quantize & export (to .mif)
quantize_and_export.py:

Loads mlp_mnist.h5.

For each layer, computes a single scale = 32767 / max(|W|, |b|).

Quantizes W and b to int16.

Writes .mif files with WIDTH = 16 and ADDRESS_RADIX = DEC, flattened row-major (addr = i * H + j).

Writes weights_meta.json describing shapes & scales.

Run:

bash
Copy code
python3 quantize_and_export.py
# Now look in mif_weights/
Check weights_meta.json for:

json
Copy code
{
  "fc0": {
    "W_shape": [784, 64],
    "b_shape": [64],
    "scale": 12345.0,
    "W_mif": "fc0_W.mif",
    "b_mif": "fc0_b.mif"
  },
  ...
}
FPGA design (Quartus) — detailed steps
The Verilog top is written to expect specific IP instance names. Use those names in IP generation or update the top-level if you prefer different names.

Create Quartus project

File → New Project Wizard

Project directory: ~/fpgaProjectNew/fpga_quartus/

Device: choose the DE2-115 Cyclone IV part (e.g. EP4CE115F29C7).

Add HDL files

Add verilog/*.v (UART, MAC, controller, top_mnist.v, etc).

Generate On-Chip Memory IPs (IP Catalog → On-Chip Memory)

Create ROM for each weight/bias .mif:

Instance names used in top: fc0_W_rom, fc0_b_rom, fc1_W_rom, fc1_b_rom.

Data width: 16

Depth: equal to #elements (e.g., fc0_W depth = 784*64 = 50176).

Point initialization file to mif_weights/<name>.mif.

Set synchronous read (1 cycle latency).

Create RAM for:

input_ram: depth = 784, width = 16, write enabled.

hidden_ram: depth = 64, width = 16, write enabled.

When configuring each IP, note the port names the IP generator exposes (address, clock, q, writedata, writeenable). Match these names in top_mnist.v or modify the top module to match IP wrappers.

Pin assignments

Connect clk50 to the on-board 50 MHz oscillator pin.

Map uart_rx_pin and uart_tx_pin to the board’s UART header pins (refer to the DE2-115 manual).

Optionally connect status LEDs.

Compile project

Start Full Compilation. Fix any port-name mismatches by editing top_mnist.v or re-generating IP with matching names.

Program FPGA

Tools → Programmer → select .sof → Start.

Confirm FPGA runs by testing UART echo or status LED from the top design.

Host protocol & host_send_image.py
Protocol

Host → FPGA: 1 byte header 0xAA, then 784 bytes of pixel intensities (0..255), row-major.

FPGA → Host: 1 byte (0..9) predicted digit.

Usage

bash
Copy code
python3 host_send_image.py --port /dev/ttyUSB0 --baud 115200 --index 0
--index selects which MNIST test image to send (script uses Keras MNIST loader).

If you use Windows, replace /dev/ttyUSB0 with COMx (e.g., COM3).

Numeric details (important)
We quantize to signed 16-bit using per-layer scale S:

ini
Copy code
q = round(float_value * S)   // stored in int16
S = 32767 / max_abs_value_in_layer
On FPGA: inputs are converted from 0..255 to Q1.15 by multiplying (approx) by 128 (i.e., 32767/255 ≈ 128.5).

Multiply: int16 * int16 → int32, accumulate into signed 64-bit to avoid overflow when summing 784 terms.

After accumulation: acc >>> 15 shift to restore scale, add bias, then saturate to int16 before storing activation.

Troubleshooting & tips
Large files in repo: do NOT commit virtualenvs or lenet-env/. Add to .gitignore. Use requirements.txt instead:

bash
Copy code
pip freeze > requirements.txt
If push fails due to large file: use git filter-branch or BFG to strip large blobs (see commands.txt in repo).

UART not responding: verify COM port, baud (115200), and header byte 0xAA is sent first.

ROM read timing: On-Chip Memory is synchronous; top-level controller must set address one cycle before using q output. The provided Verilog is written with 1-cycle read latency in mind.

Check weights: run check_mifs.py to verify shapes and element count match expected dimensions in weights_meta.json.

Development & simulation
Use ModelSim or Quartus Simulation to simulate mac_unit.v and top_mnist.v with a small test vector.

Test MAC separately with a simple Verilog testbench to ensure scaling & saturation are correct.

Example commands (convenience)
Train → export → check:

bash
Copy code
python3 train_mnist_mlp.py
python3 quantize_and_export.py
python3 check_mifs.py
Build & program (Quartus):

Create project → add Verilog + IP → Compile → Tools → Programmer → Program device

Send test image:

bash
Copy code
python3 host_send_image.py --port /dev/ttyUSB0 --index 0
License
This project is released under the MIT License — see LICENSE for details.

Acknowledgements
MNIST dataset (Yann LeCun et al.)

TensorFlow / Keras

Intel Quartus Prime
