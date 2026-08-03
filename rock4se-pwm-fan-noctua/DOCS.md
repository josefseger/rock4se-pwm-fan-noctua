# ROCK 4SE Noctua PWM Fan

Temperature-controlled PWM fan control for the Radxa ROCK 4 SE using RK3399
PWM hardware registers.

## Requirements

- Radxa ROCK 4 SE
- Home Assistant OS
- AArch64 architecture
- Compatible PWM fan hardware
- MQTT broker

## Configuration

### poll_seconds

Number of seconds between temperature checks.

### min_speed

Minimum PWM fan speed in percent.

### mqtt_host

MQTT broker hostname. With the official Mosquitto broker app this is normally:

`core-mosquitto`

### mqtt_port

MQTT broker port, normally `1883`.

### mqtt_user

MQTT username.

### mqtt_password

MQTT password.

## Hardware warning

This app accesses RK3399 hardware registers through `/dev/mem`.

It is intended specifically for the Radxa ROCK 4 SE. Do not install it on
unrelated hardware.

Verify fan voltage, ground, PWM wiring, and electrical compatibility before
starting the app.

## Tachometer wiring

Connect the Noctua green tachometer wire to ROCK 4 SE physical pin 3.

- Physical pin 3: GPIO2_A7
- Linux GPIO number: 71
- Character device mapping: `/dev/gpiochip2`, line offset 7
- Board pull-up: 4.7 kΩ to 3.0 V
- Fan tachometer: two pulses per revolution

The add-on publishes `Fan RPM` and `Tachometer Status` through MQTT Discovery.
