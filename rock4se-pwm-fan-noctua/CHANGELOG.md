# Changelog

## 0.2.1

- Added branded Home Assistant `icon.png` in the same tropical ROCK 4 SE visual style as the Ethernet LED Fix app.
- Added branded Home Assistant `logo.png` with a Noctua-inspired brown/beige fan treatment.
- No PWM control, tachometer, MQTT, or GPIO behavior changed.

## 0.2.0

- Added Noctua tachometer reading on ROCK 4 SE physical pin 3.
- Uses GPIO2_A7 through `/dev/gpiochip2`, line offset 7.
- Uses the board's onboard 4.7 kΩ pull-up to 3.0 V; no external resistor required.
- Calculates RPM from the Noctua standard two pulses per revolution.
- Added MQTT Discovery sensors for fan RPM and tachometer status.

## 0.1.0

- Initial Noctua-specific repository based on the working ROCK 4 SE PWM controller.
