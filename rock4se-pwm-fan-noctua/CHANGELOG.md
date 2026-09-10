# Changelog

## 0.3.2

- Fixed the low-level PWM controller mismatch that caused the app to exit when a configured fan speed below 25% was requested.
- The low-level controller now accepts non-zero fan speeds from 10% through 100%; explicit 0% remains supported.
- Added the RK3399 PWM controller source as `pwmctl.c` so the implementation is auditable and versioned with the app.
- The Docker image now builds `rock4se-pwmctl` from `pwmctl.c` instead of copying the stale precompiled binary.
- Preserved the verified PWM0 base address, register offsets, 1931-tick period, control value `0x13`, cold-start initialization sequence, safety checks, readback verification, and nearest-integer duty calculation.
- Repository default `min_speed` and first fan level remain 10%.
- No fan-curve selection logic, tachometer, GPIO, thermal-sensor detection, MQTT Discovery, or invalid-temperature fail-safe behavior changed.

## 0.3.1

- Confirmed the repository default minimum fan speed is 10%.
- Documented that Home Assistant preserves existing saved add-on options during upgrades, so an older saved `min_speed` value can remain after updating until the user changes it.
- No fan-curve logic, PWM hardware access, tachometer, GPIO, thermal-sensor detection, MQTT Discovery, or fail-safe behavior changed.

## 0.3.0

- Added configurable five-temperature / six-speed fan curve in the Home Assistant add-on configuration.
- Changed the default minimum fan speed from 25% to 10%.
- Changed the default first fan level from 25% to 10% below 40 °C.
- Preserved the existing remaining default curve: 35% from 40 °C, 50% from 50 °C, 70% from 60 °C, 85% from 70 °C, and 100% from 80 °C.
- Added startup validation requiring temperature thresholds to be strictly increasing.
- Preserved the existing 100% startup fail-safe and invalid-temperature fail-safe behavior.
- No PWM hardware access, tachometer, GPIO, thermal-sensor detection, or MQTT Discovery behavior changed.

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
