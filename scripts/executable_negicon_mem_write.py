import sys
import hid
from enum import Enum

# Enum for NegiconEventType
class NegiconEventType(Enum):
    Input = 0
    Output = 1
    MemWrite = 2
    Reboot = 3

# NegiconEvent class
class NegiconEvent:
    def __init__(self, event_type, id, value, controller_id, sequence):
        self.event_type = event_type
        self.id = id
        self.value = value
        self.controller_id = controller_id
        self.sequence = sequence

    def serialize(self):
        id_high, id_low = divmod(self.id, 256)
        value_high, value_low = divmod(((1 << 16) + self.value) % (1 << 16), 256)
        return [
            self.event_type.value,
            id_high,
            id_low,
            value_high,
            value_low,
            self.controller_id,
            self.sequence,
            0
        ]

# Function to send data to USB HID device using hidapi
def send_to_usb_hid(serialized_data):
    try:
        # Open the device
        h = hid.device()
        h.open(0x1209, 0x3939)  # Vendor ID and Product ID

        # Write the serialized data
        # The first byte of data sent to HID devices is often the report ID.
        # If the device does not use numbered reports, set it to 0.
        h.write([0] + serialized_data)

        h.close()
        print("Data sent successfully")
    except Exception as e:
        print(f"Error sending data: {e}")

# Main function
def main():
    if len(sys.argv) != 4:
        print("Usage: script.py <device_id> <memory_address> <data>")
        return

    # Parse command-line arguments
    device_id = int(sys.argv[1]) # Assuming device_id is decimal
    memory_address = int(sys.argv[2], 16) # Hexadecimal
    data = int(sys.argv[3], 16) # Hexadecimal

    # Create event
    event = NegiconEvent(NegiconEventType.MemWrite, device_id, data, 0, memory_address)

    # Serialize event data and send it
    serialized_data = event.serialize()
    send_to_usb_hid(serialized_data)

if __name__ == "__main__":
    main()
