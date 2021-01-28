#include <SPI.h>

// McpDigitalPot library available from https://github.com/dreamcat4/McpDigitalPot
#include <McpDigitalPot.h>

// Arduino MQTT library
#include <Ethernet.h>
#include <MQTT.h>

// Digital pins
#define POWER_PIN 7
#define VOLUME_SLAVE_SELECT_PIN 8

// Potentiometer index
#define POT_INDEX 0

// Instantiate the volumeControl object
const float rAB_ohms = 5090.00; // 5k Ohm
McpDigitalPot volumeControl = McpDigitalPot(VOLUME_SLAVE_SELECT_PIN, rAB_ohms);

// Ethernet
static uint8_t mac[] = { 0x90, 0xA2, 0xDA, 0x0D, 0x38, 0x52 };
static uint8_t ip[] = { 192, 168, 1, 10 };

// MQTT
EthernetClient ethernetClient;
MQTTClient mqtt;

// Global variables
int currentVolume = 0;
int lastPublishedVolume = -1;
boolean powered = false;
unsigned long lastAvailableMessageSentAt = 0;

/*
 * Turn the speaker power on
 */
void on() {
  digitalWrite(POWER_PIN, LOW);
  powered = true;
  Serial.println("ON");
}

/*
 * Turn the speaker power off
 */
void off() {
  digitalWrite(POWER_PIN, HIGH);
  powered = false;
  Serial.println("OFF");
}

/*
 * Set the speaker volume to the given volume (range 0 - 128)
 */
void setVolume(int volume) {
  if (volume < 0 || volume > 128) {
    Serial.print("INVALID VOLUME ");
    Serial.println(volume);
    return;
  }

  if (volume == 0) {
    off();
  } else {
    on();
  }

  Serial.print("SET VOLUME ");
  Serial.println(volume);
  volumeControl.writeResistance(POT_INDEX, volume);
  currentVolume = volume;
}

// Called whenever an MQTT message is received
void messageReceived(String &topic, String &payload) {
  if (topic == "home/speakers/setVolume") {
    setVolume(payload.toInt());
  } else if (topic == "home/speakers/volume" && lastPublishedVolume == -1) {
    lastPublishedVolume = payload.toInt();
    setVolume(lastPublishedVolume);
  }
}

void connect() {
  Serial.print("connecting...");
  while (!mqtt.connect("volume-control")) {
    Serial.print(".");
    delay(1000);
  }

  Serial.println("\nconnected!");

  mqtt.subscribe("home/speakers/+");
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

  // Initialize ethernet
  Ethernet.begin(mac, ip);

  // Initialize MQTT
  mqtt.begin("192.168.1.8", ethernetClient);
  mqtt.onMessage(messageReceived);
  mqtt.setWill("home/speakers/available", "false", true, 0);
  connect();

  Serial.print("> ");
}

void loop() {
  if (!mqtt.connected()) {
    connect();
  }

  mqtt.loop();

  // Publish an availability message every second
  if (millis() - lastAvailableMessageSentAt > 1000) {
    lastAvailableMessageSentAt = millis();
    mqtt.publish("home/speakers/available", "true", true, 0);
  }

  // Publish a volume update if the volume has changed
  if (lastPublishedVolume != -1 && currentVolume != lastPublishedVolume) {
    mqtt.publish("home/speakers/volume", String(currentVolume), true, 0);
    lastPublishedVolume = currentVolume;
  }
}
