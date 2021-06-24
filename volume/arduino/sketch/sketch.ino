#include <SPI.h>

// McpDigitalPot library available from https://github.com/dreamcat4/McpDigitalPot
#include <McpDigitalPot.h>

// Digital pins
#define POWER_PIN 7
#define VOLUME_SLAVE_SELECT_PIN 8

// Potentiometer index
#define POT_INDEX 0

// Instantiate the volumeControl object
const float rAB_ohms = 5090.00; // 5k Ohm
McpDigitalPot volumeControl = McpDigitalPot(VOLUME_SLAVE_SELECT_PIN, rAB_ohms);

/*
 * Turn the speaker power on
 */
void on() {
  digitalWrite(POWER_PIN, LOW);
  Serial.println("ON");
}

/*
 * Turn the speaker power off
 */
void off() {
  digitalWrite(POWER_PIN, HIGH);
  Serial.println("OFF");
}

/*
 * Set the speaker volume to the given volume (range 0 - 128)
 */
void setVolume(int volume) {
  if (volume < 0 || volume > 128) {
    Serial.print("INVALID_VOLUME ");
    Serial.println(volume);
    return;
  }

  Serial.print("SET_VOLUME ");
  Serial.println(volume);
  volumeControl.writeResistance(POT_INDEX, volume);
}

void setup() {
  int state = 0;

  // initialize SPI:
  SPI.begin();

  // initialize Serial
  Serial.begin(9600);

  // initialize digital pins
  digitalWrite(POWER_PIN, HIGH);
  pinMode(POWER_PIN, OUTPUT);

  // Initialize digital pot
  volumeControl.scale = 128.0;
  volumeControl.writeResistance(POT_INDEX, 0);
}

void loop() {
  String input = Serial.readStringUntil('\n');
  input.trim();

  if (input == "on") {
    on();
  } else if (input == "off") {
    off();
  } else if (input != "") {
    setVolume(input.toInt());
  }
}
