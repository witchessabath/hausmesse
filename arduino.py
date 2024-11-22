import serial

# Configure the serial port
ser = serial.Serial('/dev/ttyACM0', 9600)  # Adjust the port and baud rate as needed

# Define the scaling factor based on the voltage divider
scaling_factor = 4.0  # 20V / 5V

while True:
    if ser.in_waiting > 0:
        line = ser.readline().decode('utf-8').rstrip()
        try:
            measured_voltage = float(line)
            actual_voltage = measured_voltage * scaling_factor
            print(f"Measured Voltage: {measured_voltage}V, Actual Voltage: {actual_voltage}V")
            
            # Read the existing lines from the file
            try:
                with open('voltage.txt', 'r') as file:
                    lines = file.readlines()
            except FileNotFoundError:
                lines = []

            # Append the new line
            lines.append(f"{actual_voltage}\n")

            # Keep only the last 10 lines
            lines = lines[-10:]

            # Write the lines back to the file
            with open('voltage.txt', 'w') as file:
                file.writelines(lines)
                
        except ValueError:
            print("Received invalid data")
