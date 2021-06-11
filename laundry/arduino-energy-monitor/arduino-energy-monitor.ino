#include "EmonLib.h"

EnergyMonitor washingMachineMonitor;
EnergyMonitor dryerMonitor;

void setup() {
  Serial.begin(9600);

  washingMachineMonitor.current(A1, 90);
  dryerMonitor.current(A2, 90);
}

void loop() {
  double washingMachineCurrent = washingMachineMonitor.calcIrms(1480);
  double dryerCurrent = dryerMonitor.calcIrms(1480);
  Serial.print(washingMachineCurrent);
  Serial.print(" ");
  Serial.println(dryerCurrent);
}
