#!/bin/env python
import hid
from enum import IntEnum

# Define the vendor and product IDs
VENDOR_ID = 0x1209
PRODUCT_ID = 0x3939

# Define the NegiconEventType enum
class NegiconEventType(IntEnum):
    Input = 0
    Output = 1
    MemWrite = 2
    Reboot = 3
    SetControllerId = 4

# Helper functions to convert bytes to u16 and i16
def make_u16(high, low):
    return (high << 8) | low

def make_i16(high, low):
    value = make_u16(high, low)
    return value if value < 32768 else value - 65536

# Define the NegiconEvent class
class NegiconEvent:
    def __init__(self, event_type, id, sub_id, value, controller_id, sequence):
        self.event_type = event_type
        self.id = id
        self.sub_id = sub_id
        self.value = value
        self.controller_id = controller_id
        self.sequence = sequence

    @staticmethod
    def deserialize(data):
        event_type = NegiconEventType.Input if data[0] & 0b1000_0000 != 0 else NegiconEventType(data[0])
        sub_id = data[0] & 0b0111_1111
        id = make_u16(data[1], data[2])
        value = make_i16(data[3], data[4])
        controller_id = data[5]
        sequence = data[6]

        return NegiconEvent(event_type, id, sub_id, value, controller_id, sequence)

    def __str__(self):
        return f"NegiconEvent(type={self.event_type}, id={self.id}, sub_id={self.sub_id}, value={self.value}, controller_id={self.controller_id}, sequence={self.sequence})"

# Main function to read and decode HID messages
def read_hid_messages():
    # Open the HID device
    device = hid.device()
    device.open(VENDOR_ID, PRODUCT_ID)

    try:
        while True:
            data = device.read(8)
            if data:
                event = NegiconEvent.deserialize(data)
                print(event)
    except KeyboardInterrupt:
        print("Stopped reading HID messages.")
    finally:
        device.close()

# Run the script
if __name__ == "__main__":
    read_hid_messages()
