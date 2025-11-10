import subprocess
import re
import os

def run_command(command):
    """Runs a command and returns its stdout."""
    result = subprocess.run(command, shell=True, capture_output=True, text=True, executable='/bin/bash')
    if result.returncode != 0:
        print(f"Error running command: {command}")
        print(f"Stderr: {result.stderr}")
        return None
    return result.stdout

def main():
    correct_matches = 0
    start_index = 0
    end_index = 9999
    total_images_to_test = end_index - start_index + 1

    # Read original content of get_mnist_image.py
    with open("get_mnist_image.py", "r") as f:
        original_get_image_content = f.read()

    # Find the line to replace in get_mnist_image.py
    image_index_line_pattern = re.compile(r"image_index = \d+")

    # Compile Verilog once at the beginning
    print("--- Compiling Verilog ---")
    compile_output = run_command("iverilog -o mnist_mlp_tb mnist_mlp.v mnist_mlp_tb.v")
    if compile_output is None:
        # Revert get_mnist_image.py before exiting
        with open("get_mnist_image.py", "w") as f:
            f.write(original_get_image_content)
        return

    for image_index in range(start_index, end_index + 1):
        print(f"--- Testing image index: {image_index} ---")

        # 1. Modify get_mnist_image.py and get correct label
        modified_get_image_content = image_index_line_pattern.sub(f"image_index = {image_index}", original_get_image_content)
        with open("get_mnist_image.py", "w") as f:
            f.write(modified_get_image_content)

        get_image_output = run_command("source lenet-env/bin/activate && python3 get_mnist_image.py")
        if get_image_output is None:
            continue

        correct_label_match = re.search(r"The correct label for this image is: (\d+)", get_image_output)
        if not correct_label_match:
            print("Could not find correct label in get_image.py output.")
            continue
        correct_label = int(correct_label_match.group(1))
        print(f"Correct label: {correct_label}")

        # 3. Run Verilog simulation
        sim_output = run_command("vvp mnist_mlp_tb")
        if sim_output is None:
            continue

        predicted_digit_match = re.search(r"Predicted digit on LEDR\[3:0\] is:\s*(\d+)", sim_output)
        if not predicted_digit_match:
            print("Could not find predicted digit in simulation output.")
            continue
        predicted_digit = int(predicted_digit_match.group(1))
        print(f"Predicted digit: {predicted_digit}")

        # 4. Compare and count
        if correct_label == predicted_digit:
            correct_matches += 1
            print("Result: MATCH")
        else:
            print("Result: MISMATCH")

        # Print current accuracy every 10 images
        images_tested = image_index - start_index + 1
        if images_tested % 10 == 0:
            current_accuracy = (correct_matches / images_tested) * 100
            print(f"--- Current accuracy after {images_tested} images: {current_accuracy:.2f}% ---")

    print(f"\n--- Test Suite Finished ---")
    print(f"Total correct matches: {correct_matches} out of {total_images_to_test}")

    # Revert get_mnist_image.py to its original content
    with open("get_mnist_image.py", "w") as f:
        f.write(original_get_image_content)

    # os.remove("mnist_mlp_tb") # Keep this for user to run manually

if __name__ == "__main__":
    main()
