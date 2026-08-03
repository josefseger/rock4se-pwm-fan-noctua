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
