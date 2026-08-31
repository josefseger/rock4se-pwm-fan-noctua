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

Default: `5` seconds.

### min_speed

Absolute minimum PWM fan speed in percent. If any configured fan level is lower
than this value, `min_speed` wins.

Default: `10` percent.

### Configurable fan curve

The fan curve consists of five temperature thresholds and six speed levels.
The defaults are:

- Below `temp_level_1` (`40 °C`): `speed_level_1` = `10%`
- From `40 °C` to below `temp_level_2` (`50 °C`): `speed_level_2` = `35%`
- From `50 °C` to below `temp_level_3` (`60 °C`): `speed_level_3` = `50%`
- From `60 °C` to below `temp_level_4` (`70 °C`): `speed_level_4` = `70%`
- From `70 °C` to below `temp_level_5` (`80 °C`): `speed_level_5` = `85%`
- At or above `80 °C`: `speed_level_6` = `100%`

The temperature thresholds must be strictly increasing:

`temp_level_1 < temp_level_2 < temp_level_3 < temp_level_4 < temp_level_5`

If they are not strictly increasing, the add-on exits with a fatal configuration
error instead of running with an ambiguous fan curve.

### tach_window_seconds

Number of seconds used for each tachometer RPM measurement window.

Default: `2` seconds.

### mqtt_host

MQTT broker hostname. With the official Mosquitto broker app this is normally:

`core-mosquitto`

### mqtt_port

MQTT broker port, normally `1883`.

### mqtt_user

MQTT username.

### mqtt_password

MQTT password.

## Safety behavior

On startup, the PWM controller is initialized at `100%` as a fail-safe before
the normal temperature-controlled loop begins.

If the temperature reading is invalid, the fan is also forced to `100%`.

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
