import os
import time
import digitalio
import paho.mqtt.client as mqtt

SUCCESS = 0
BROKER_HOST = os.environ.get("BROKER_HOST")
ISCSI_HOST = os.environ.get("ISCSI_HOST")
ISCSI_PORT = os.environ.get("ISCSI_PORT", "3260")
PORTAL = "{host}:{port}".format(host=ISCSI_HOST, port=ISCSI_PORT)
BASE_IQN = os.environ.get("BASE_IQN")

INPUT_TARGET_MAP = {
    2: {
        "target": "xbox-one",
        "host": 1
    },
    4: {
        "target": "xbox360",
        "host": 2
    },
    7: {
        "target": "ps4",
        "host": 3
    }
}

client = mqtt.Client(client_id='game-drive')

current_iscsi_target = None
host_indicators = []
for pin in [148, 147, 131, 154]:
    input = digitalio.DigitalInOut(digitalio.Pin(pin))
    input.direction = digitalio.Direction.INPUT
    host_indicators.append(input)

next_host = digitalio.DigitalInOut(digitalio.Pin(156))
next_host.direction = digitalio.Direction.OUTPUT
next_host.value = digitalio.Pin.HIGH
time.sleep(0.01)

def cycle_host():
    next_host.value = digitalio.Pin.LOW
    time.sleep(0.01)
    next_host.value = digitalio.Pin.HIGH
    time.sleep(0.01)

def get_active_host():
    for index, host in enumerate(host_indicators):
        if host.value == digitalio.Pin.LOW:
            return index + 1

def set_active_host(index):
    while get_active_host() != index:
        cycle_host()

def connect_iscsi(target):
    global current_iscsi_target
    full_iqn = "{base_iqn}:{target}".format(base_iqn=BASE_IQN, target=target)
    device = "/dev/disk/by-path/ip-{portal}-iscsi-{iqn}-lun-1".format(portal=PORTAL, iqn=full_iqn)

    status = os.system("iscsiadm --mode discovery --type sendtargets --portal '{portal}'".format(portal=PORTAL))
    if status != SUCCESS:
        return status

    status = os.system("iscsiadm --mode node --targetname '{iqn}' --portal '{portal}' --login".format(iqn=full_iqn, portal=PORTAL))
    if status != SUCCESS:
        return status

    time.sleep(1)
    status = os.system("modprobe g_mass_storage file='{device}' stall=0".format(device=device))
    if status == SUCCESS:
        current_iscsi_target = target
    return status

def disconnect_iscsi(target):
    global current_iscsi_target
    full_iqn = "{base_iqn}:{target}".format(base_iqn=BASE_IQN, target=target)

    status = os.system("modprobe --remove g_mass_storage")
    if status != SUCCESS:
        return status

    status = os.system("iscsiadm --mode node --targetname '{iqn}' --portal '{portal}' --logout".format(iqn=full_iqn, portal=PORTAL))
    if status == SUCCESS:
        current_iscsi_target = None
    return status

def init_mqtt():
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    client.will_set('home/gameDrive/available',
                    payload='false',
                    retain=True)
    client.connect(BROKER_HOST)
    client.publish('home/gameDrive/available',
                   payload='true',
                   retain=True)

def on_connect(client, userdata, flags, rc):
    print('Connected with result code ' + str(rc))
    client.subscribe('home/hdmiSwitch/input')

def on_disconnect(client, userdata, rc):
    print('Disconnected with result code ' + str(rc))
    exit(1)

def on_message(client, userdata, message):
    payload = int(message.payload.decode('utf-8'))
    input = INPUT_TARGET_MAP[payload]
    if input is not None:
        print("input={} host={} target={}".format(payload, input["host"], input["target"]))

        if current_iscsi_target is not None:
            status = disconnect_iscsi(current_iscsi_target)
            if status != SUCCESS:
                return status
        set_active_host(input["host"])
        connect_iscsi(input["target"])

init_mqtt()
client.loop_forever()
