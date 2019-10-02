// This example demonstrates control over SPI to the Microchip McpDigitalPot Digital potentometer
// SPI Pinouts are for Arduino Uno and Arduino Duemilanove board (will differ for Arduino MEGA)

// Download these into your Sketches/libraries/ folder...

// The Spi library by Cam Thompson. It was originally part of FPU library (micromegacorp.com)
// Available from http://arduino.cc/playground/Code/Fpu or http://www.arduino.cc/playground/Code/Spi
// Including SPI.h vv below initializea the MOSI, MISO, and SPI_CLK pins as per ATMEGA 328P
#include <SPI.h>

// McpDigitalPot library available from https://github.com/dreamcat4/McpDigitalPot
#include <McpDigitalPot.h>

// Wire up the SPI Interface common lines:
// #define SPI_CLOCK            13 //arduino   <->   SPI Slave Clock Input     -> SCK (Pin 02 on McpDigitalPot DIP)
// #define SPI_MOSI             11 //arduino   <->   SPI Master Out Slave In   -> SDI (Pin 03 on McpDigitalPot DIP)
// #define SPI_MISO             12 //arduino   <->   SPI Master In Slave Out   -> SDO (Pin 13 on McpDigitalPot DIP)

// Then choose any other free pin as the Slave Select (pin 10 if the default but doesnt have to be)
#define MCP_DIGITAL_POT_SLAVE_SELECT_PIN 10 //arduino   <->   Chip Select               -> CS  (Pin 01 on McpDigitalPot DIP)

// Its recommended to measure the rated end-end resistance (terminal A to terminal B)
// Because this can vary by a large margin, up to -+ 20%. And temperature variations.
float rAB_ohms = 5090.00; // 5k Ohm

// Instantiate McpDigitalPot object, with default rW (=117.5 ohm, its typical resistance)
McpDigitalPot digitalPot = McpDigitalPot( MCP_DIGITAL_POT_SLAVE_SELECT_PIN, rAB_ohms );

// rW - Wiper resistance. This is a small additional constant. To measure it
// use the example, setup(). Required for accurate calculations (to nearest ohm)
// Datasheet Page 5, gives typical values MIN=75ohm, MAX @5v=160ohm,@2.7v=300ohm
// Usually rW should be somewhere between 100 and 150 ohms.
// Instantiate McpDigitalPot object, after measuring the real rW wiper resistance
// McpDigitalPot digitalPot = McpDigitalPot( MCP_DIGITAL_POT_SLAVE_SELECT_PIN, rAB_ohms, rW_ohms );

void setup()
{
  // initialize SPI:
  SPI.begin(); 
  
  // First measure the the wiper resistance, called rW
  digitalPot.setPosition(0, 0); // rAW = rW_ohms
  digitalPot.setPosition(1, 0); // rAW = rW_ohms
  delay(5000);
  
  // (optional)
  // Scale to 100.0 for a percentage, or 1.0 for a fraction
  // Eg if scale=100, then setResistance(0, 100) = max rAW resistance
  // Eg    scale=1.0, then setResistance(0, 1.0) = max rAW resistance
  // digitalPot.scale = 1.0;

  digitalPot.scale = 100.0; // For the timeout example, below

  // digitalPot.setResistance(0, 40); // set pot0 rAW = 40% of max value
  // digitalPot.setResistance(1, 80); // set pot1 rAW = 80% of max value
  // 
  // delay(5000);
  // 
  // digitalPot.setResistance(0, 5);  // set pot0 rAW =  5% of max value
  // digitalPot.setResistance(1, 50); // set pot1 rAW = 50% of max value

  // Go back to using ohms
  // digitalPot.scale = McpDigitalPot.rAB_ohms;
}




// Cycle the wipers around at 20% increments, changing every 2 seconds
long timeoutInterval = 2000;
long previousMillis = 0;
float counter = 0.0;

void timeout()
{
  if(counter > 100.0)
    counter = 0.0;

  // These resistances are just percentages of 100
  digitalPot.setResistance(0, counter);
  digitalPot.setResistance(1, 100 - counter); // Invert the wiper1

  counter += 20.0;
}

void loop()
{
  if (  millis() - previousMillis > timeoutInterval )
  {
    timeout();
    previousMillis = millis();
  }
  // Loop.
}


