# ROCK 4SE PWM Fan Noctua

Home Assistant app repository for a Noctua NF-A4x20 5V PWM fan on the Radxa ROCK 4 SE.

This repository starts from the verified PWM implementation in
`josefseger/rock4se-pwm-fan`. The Noctua-specific fan curve and tachometer
input will be added and verified in subsequent versions.

## Planned wiring

- Yellow: +5 V, physical pin 2
- Black: GND, physical pin 6
- Blue: PWM, physical pin 11
- Green: tachometer, proposed physical pin 3 after runtime verification

## Installation URL

`https://github.com/josefseger/rock4se-pwm-fan-noctua`
