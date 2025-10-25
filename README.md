# fpga-mnist
MNIST digit recognition on DE2-115 FPGA
# FPGA MNIST Classifier 🧠⚙️

This project implements a **Multi-Layer Perceptron (MLP)** neural network trained on the **MNIST handwritten digits dataset**, and deploys the quantized model on an **FPGA** for inference. The host communicates with the FPGA via UART to send test images and receive predictions.

---

## 🗂️ Project Structure

fpga-mnist/
├── mif_weights/ # Quantized weight files (converted to .mif for FPGA)
├── verilog/ # HDL source files for the FPGA implementation
├── check_mifs.py # Script to verify generated .mif files
├── commands.txt # Common Quartus and Python commands
├── host_send_image.py # Host script to send test images over UART
├── mlp_mnist.h5 # Trained MLP model (Keras format)
├── quantize_and_export.py # Quantizes trained model and exports weights
├── train_mnist_mlp.py # Trains the MLP model on MNIST
├── README.md # Project documentation (this file)
└── .gitignore # Ignored files (e.g., env, cache, large libs)

yaml
Copy code

---

## 🧩 Workflow Overview

1. **Train the MLP model**
   ```bash
   python3 train_mnist_mlp.py
Quantize and export weights
Converts the trained model into FPGA-friendly .mif files.

bash
Copy code
python3 quantize_and_export.py
Check MIF files

bash
Copy code
python3 check_mifs.py
Load Verilog design in Quartus

Create a new Quartus project.

Add files from the verilog/ directory.

Generate ROM/RAM IPs:

fc0_W_rom, fc0_b_rom

fc1_W_rom, fc1_b_rom

input_ram, hidden_ram

Compile the design and program the FPGA.

Send test images from host

bash
Copy code
python3 host_send_image.py --port /dev/ttyUSB0 --index 5
(Replace /dev/ttyUSB0 with your actual serial port.)

🧠 Model Details
Architecture: 2-layer MLP

Input: 784 (28×28)

Hidden: 64 neurons

Output: 10 classes (digits 0–9)

Activation: ReLU

Optimizer: Adam

Loss: Categorical Crossentropy

Dataset: MNIST (60,000 training, 10,000 test images)

💻 Requirements
Python environment
bash
Copy code
pip install tensorflow numpy matplotlib pyserial
If you have no GPU, install the CPU-only version:

bash
Copy code
pip install tensorflow==2.16.1
FPGA toolchain
Quartus Prime (Intel)

ModelSim (optional) for simulation

⚡ UART Communication
The host_send_image.py script sends a single MNIST image to the FPGA via UART.
The FPGA computes the prediction and sends the output label back.

Example:

bash
Copy code
python3 host_send_image.py --port /dev/ttyUSB0 --index 3
Output:

arduino
Copy code
Sending image 3 ...
Predicted digit: 7
🧾 License
This project is open-source under the MIT License.

✨ Acknowledgments
MNIST dataset by Yann LeCun et al.

TensorFlow/Keras for model training

Intel Quartus Prime for FPGA development

