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

- Increased the onboard tachometer pull-up from 1.5 kOhm to 4.7 kOhm on physical pin 3 / GPIO2_A7.
- Updated tachometer startup logging to report the 4.7 kOhm pull-up.
- No PWM, temperature-control, MQTT, GPIO line, or RPM calculation behavior changed.

## 0.2.0

- Added Noctua fan tachometer monitoring on physical pin 3 / GPIO2_A7 (`/dev/gpiochip2` line 7).
- Added Home Assistant MQTT Discovery sensors for fan RPM and fan status.
- Added configurable tachometer measurement window.
- Added startup diagnostics for tachometer pin, pull-up resistor, and pulses per revolution.
- Added RPM status logging including STARTING, OK, LOW and STOPPED states.
- Preserved the existing verified PWM controller and temperature fan curve.

## 0.1.0

- Created separate Noctua repository from the verified ROCK 4 SE PWM fan app.
- Renamed the app, slug, MQTT topics, MQTT device identifiers and discovery entities.
- Retained the verified RK3399 PWM binary and physical pin 11 PWM control.
- Tachometer support is not implemented yet.
