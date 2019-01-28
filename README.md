# Home Automation

This is a repository of scripts I use to control things around my house.
Everything is deployed on a stack of Raspberry Pi 3's running a
Kubernetes cluster in my living room (I know that it's overkill, but I
wanted to learn more about how Kubernetes works). The scripts in here 
are highly specific to my hardware, so I don't really expect this to be 
useful to anyone else, but the snips-action-handlers might be of interest
to someone who's curious about how to listen for Snips messages over
MQTT.

Below I've detailed what you'll find in each directory.

## Projector

MQTT control for an Acer P6500 projector. The projector has a built-in
webpage that acts like a replacement for the remote control, with the
added benefit that you can read the current projector state from it.
I sniffed the traffic on that page and discovered that it uses a
not-quite-JSON definitely-not-REST API. This script replicates
those API calls in response to MQTT events.

## Volume

MQTT control for an Arduino-based volume control replacement I built.
The Arduino source code is [here](https://github.com/davesilva/volume.xxx).
The original project had the Arduino running a webserver with a built-in
webpage that communicated over a RESTful JSON API. This project replaces
that webpage and bridges the gap between the MQTT bus and that API.

## Nerves

This directory contains a controller for an HDMI Switch written in
Elixir. The switch has a serial port on the back for reading and
writing the state. The Elixir app just listens on the MQTT bus and
relays those commands over the serial port.

## TV

The newest addition to the family, this script runs on a Raspberry Pi Zero
equipped with an infrared LED attached for controling a Toshiba television in
using Lirc.

## Web

The webpage (intended for use on a phone) is written using Vue.js and 
MQTT.js to connect to the MQTT bus over a websocket.

## Snips Action Handlers

Snips already communicates over MQTT, so this script just listens
on the bus for intents, and then fires off MQTT messages to the
other components in response.

## Database

Mostly for debugging, this just listens to Snips intents and writes them
out to a SQLite database.

## Mosquitto

Dockerfile and configuration for running Mosquitto on Kubernetes.

## Kubernetes

Kubernetes resource templates for deploying the apps.
