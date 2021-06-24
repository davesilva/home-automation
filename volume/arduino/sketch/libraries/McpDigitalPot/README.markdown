### McpDigitalPot

A C++ object to control the Microchip MCP414X/416X/424X/426X family of Digital Potentiometers and Rheostats. For the Arduino Platform.

### Introduction

McpDigitalPot is a simple object which allows your Arduino to control the MCP414X/416X/424X/426X family of digital potentiometers and rheostats, to set wiper positions etc. To use, we just wire up the SPI bus and instantiate a new object. The chip powers up with the wiper state as per the value stored in its non-volatile (EEPROM) memory. This library may also work with other MCP digital potentiometer devices, and/or other AVR microcontroller devices after some tweaking. This library was tested on Arduino UNO and Nano.

### Features

* Generally fast SPI operation (tested up to 8Mhz)
* Generic example (works with all 328P Arduinos)
* Requires only very minor modifications for Arduino MEGA.
* Can instantiate multiple McpDigitalPot objects, each with unique slave select
* Very simple interface requiring little configuration
* Works with other devices in this series (see below the Compatibility section)
* Individually address each wiper
* Read/write the potentiometer values as either the nearest rounded wiper resistance (in ohms), or wiper position (0-256).
* Optionally write the wiper value to non-volatile memory (EEPROM in MCP4x[4|6]x devices only)

### Requirements

* [MCP414X/416X/424X/426X Product Datasheet](ww1.microchip.com/downloads/en/DeviceDoc/22059b.pdf)*
* [Arduino SPI Library](http://arduino.cc/en/Reference/SPI)

\* Sorry, but the previous series of Microchip Digital Potentiometers (any with a total of 5 digits in their name eg 42100) had a very different command syntax and arent supported. They are listed on Page 29 of [the previous MCP 4Xxxx Data Sheet](http://ww1.microchip.com/downloads/en/devicedoc/11195c.pdf).

### Getting Started

Pretty much everything is explained within the example sketch file. Open McpDigitalPotExample.pde in Arduino IDE and upload it to your microcontroller device. Check that all of the SPI interface pins are connected OK for your device.

Dreamcat4


### Compatibility

This library is broadly compatible with the other devices in this series. They are: Microchip MCP4131, MCP4132, MCP4231, MCP4232, MCP4141, MCP4142, MCP4241, MCP4242, MCP4151, MCP4152, MCP4251, MCP4252, MCP4161, MCP4162, MCP4261, MCP4262. Just adjust this line in the header file as appropriate:

    const static unsigned int resolution      = resolution_8bit;

### Credit

* Mcp4261 Version 1 - By Dreamcat4.
* McpDigitalPot - fork by teabot. Uses Arduino SPI, finer-grained access to non-volatile operations.

