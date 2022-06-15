#!/usr/bin/python3 -u

from adafruit_mcp230xx.mcp23008 import MCP23008
import asyncio
import board
import busio
from digitalio import Direction, Pull, DigitalInOut
import os
import paho.mqtt.client as mqtt
import time

def on_connect(client, userdata, flags, rc):
    print('Connected with result code ' + str(rc))

    client.subscribe('home/laundry/#', qos=1)

def on_disconnect(client, userdata, rc):
    print('Disconnected with result code ' + str(rc))
    exit(1)

def on_message(client, userdata, message):
    global active_light
    topic = message.topic
    payload = message.payload.decode('utf-8')

    if topic.endswith('washingMachine/owner'):
        print("received owner=" + payload)

        if payload.isnumeric() and lights[int(payload)] != active_light:
            active_light = lights[int(payload)]
            stop_prompt_mode()
        if payload == 'unknown' and active_light is not None:
            active_light = None
            set_all_lights(False)
    if topic.endswith('washingMachine/running') and payload == 'true' and active_light is None:
        start_prompt_mode()
    if topic.endswith('washingMachine/full') and payload == 'false':
        stop_prompt_mode()

def set_all_lights(value):
    for light in lights:
        set_light(light, value)

def set_light(light, value, retry=0):
    try:
        light.value = value
    except OSError:
        print("ERROR")
        if retry < 50:
            time.sleep(0.1)
            return set_light(light, value, retry + 1)
        else:
            raise

def get_button(button, retry=0):
    try:
        return button.value
    except OSError:
        if retry < 50:
            time.sleep(0.1)
            return get_button(button, retry + 1)
        else:
            raise

def process_buttons():
    global active_light

    for index, (button, light) in enumerate(zip(buttons, lights)):
        if not get_button(button):
            if light != active_light:
              active_light = light
              stop_prompt_mode()
              print("publish owner=" + str(index))
              client.publish('home/laundry/washingMachine/owner',
                             payload=index,
                             qos=1,
                             retain=True)
            return

def display_prompt():
    for index, light in enumerate(lights):
        set_light(light, int(time.time() / 0.2) % 5 == index)

def display_active_light():
    global active_light, previous_active_light

    if active_light is None:
        set_all_lights(False)
        previous_active_light = None
    elif active_light != previous_active_light:
        set_all_lights(False)
        set_light(active_light, True)
        previous_active_light = active_light

def start_prompt_mode():
    global prompt_mode
    if not prompt_mode:
        print("prompt_mode=true")
        prompt_mode = True

def stop_prompt_mode():
    global prompt_mode
    if prompt_mode:
        print("prompt_mode=false")
        prompt_mode = False

def init_mqtt():
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    client.will_set('home/laundry/washingMachine/owner/available',
                    payload='false',
                    retain=True)
    client.connect(os.environ.get('BROKER_HOST'))
    client.publish('home/laundry/washingMachine/owner/available',
                   payload='true',
                   retain=True)

def init_gpio():
    for button in buttons:
        button.direction = Direction.INPUT
        button.pull = Pull.UP

    for light in lights:
        light.direction = Direction.OUTPUT
        light.value = False

    washing_machine_door.direction = Direction.INPUT
    washing_machine_door.pull = Pull.DOWN
    dryer_door.direction = Direction.INPUT
    dryer_door.pull = Pull.DOWN

client = mqtt.Client(client_id='laundry-view-py')
i2c = busio.I2C(board.SCL, board.SDA)
io_expander1 = MCP23008(i2c, address=0x20)
io_expander2 = MCP23008(i2c, address=0x24)
washing_machine_door = DigitalInOut(board.D6)
dryer_door = DigitalInOut(board.D13)

buttons = [
    io_expander2.get_pin(2),
    io_expander2.get_pin(4),
    io_expander2.get_pin(6),
    io_expander1.get_pin(4),
    io_expander1.get_pin(6)
]
lights = [
    io_expander2.get_pin(3),
    io_expander2.get_pin(5),
    io_expander2.get_pin(7),
    io_expander1.get_pin(5),
    io_expander1.get_pin(7)
]

previous_active_light = None
active_light = None
washing_machine_door_closed = None
dryer_door_closed = None
prompt_mode = False

init_gpio()
init_mqtt()

while True:
    process_buttons()

    if washing_machine_door.value != washing_machine_door_closed:
        washing_machine_door_closed = washing_machine_door.value
        client.publish('home/laundry/washingMachine/door',
                       payload='closed' if washing_machine_door_closed else 'open',
                       qos=1,
                       retain=True)

    if dryer_door.value != dryer_door_closed:
        dryer_door_closed = dryer_door.value
        client.publish('home/laundry/dryer/door',
                       payload='closed' if dryer_door_closed else 'open',
                       qos=1,
                       retain=True)

    client.loop(timeout=0.1)
    if prompt_mode:
        display_prompt()
    else:
        display_active_light()
    time.sleep(0.1)
