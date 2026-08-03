#!/bin/sh
set -eu

OPTIONS=/data/options.json

json_string() {
  key="$1"
  sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$OPTIONS" | head -1
}

json_number() {
  key="$1"
  sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$OPTIONS" | head -1
}

POLL_SECONDS="$(json_number poll_seconds)"
MIN_SPEED="$(json_number min_speed)"
TACH_WINDOW_SECONDS="$(json_number tach_window_seconds)"
MQTT_HOST="$(json_string mqtt_host)"
MQTT_PORT="$(json_number mqtt_port)"
MQTT_USER="$(json_string mqtt_user)"
MQTT_PASSWORD="$(json_string mqtt_password)"

POLL_SECONDS="${POLL_SECONDS:-5}"
MIN_SPEED="${MIN_SPEED:-25}"
TACH_WINDOW_SECONDS="${TACH_WINDOW_SECONDS:-2}"
MQTT_HOST="${MQTT_HOST:-core-mosquitto}"
MQTT_PORT="${MQTT_PORT:-1883}"

STATE_TOPIC=rock4se/noctua_fan/state
AVAILABILITY_TOPIC=rock4se/noctua_fan/availability

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

mqtt_pub() {
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" \
    -u "$MQTT_USER" -P "$MQTT_PASSWORD" "$@"
}

publish_discovery() {
  mqtt_pub -r -t homeassistant/sensor/rock4se_noctua_cpu_temperature/config -m \
'{"name":"CPU Temperature","unique_id":"rock4se_noctua_cpu_temperature","state_topic":"rock4se/noctua_fan/state","value_template":"{{ value_json.temperature }}","unit_of_measurement":"°C","device_class":"temperature","state_class":"measurement","availability_topic":"rock4se/noctua_fan/availability","payload_available":"online","payload_not_available":"offline","device":{"identifiers":["rock4se_noctua_pwm_fan"],"name":"ROCK 4SE Noctua PWM Fan","manufacturer":"Radxa","model":"ROCK 4 SE"}}'
  mqtt_pub -r -t homeassistant/sensor/rock4se_noctua_fan_speed/config -m \
'{"name":"Fan Speed","unique_id":"rock4se_noctua_fan_speed","state_topic":"rock4se/noctua_fan/state","value_template":"{{ value_json.speed }}","unit_of_measurement":"%","state_class":"measurement","availability_topic":"rock4se/noctua_fan/availability","payload_available":"online","payload_not_available":"offline","device":{"identifiers":["rock4se_noctua_pwm_fan"],"name":"ROCK 4SE Noctua PWM Fan","manufacturer":"Radxa","model":"ROCK 4 SE"}}'
  mqtt_pub -r -t homeassistant/sensor/rock4se_noctua_pwm_duty_cycle/config -m \
'{"name":"PWM Duty Cycle","unique_id":"rock4se_noctua_pwm_duty_cycle","state_topic":"rock4se/noctua_fan/state","value_template":"{{ value_json.duty_cycle }}","state_class":"measurement","availability_topic":"rock4se/noctua_fan/availability","payload_available":"online","payload_not_available":"offline","device":{"identifiers":["rock4se_noctua_pwm_fan"],"name":"ROCK 4SE Noctua PWM Fan","manufacturer":"Radxa","model":"ROCK 4 SE"}}'
  mqtt_pub -r -t homeassistant/sensor/rock4se_noctua_fan_rpm/config -m \
'{"name":"Fan RPM","unique_id":"rock4se_noctua_fan_rpm","state_topic":"rock4se/noctua_fan/state","value_template":"{{ value_json.rpm }}","unit_of_measurement":"rpm","state_class":"measurement","icon":"mdi:fan","availability_topic":"rock4se/noctua_fan/availability","payload_available":"online","payload_not_available":"offline","device":{"identifiers":["rock4se_noctua_pwm_fan"],"name":"ROCK 4SE Noctua PWM Fan","manufacturer":"Radxa / Noctua","model":"ROCK 4 SE + NF-A4x20 5V PWM"}}'
  mqtt_pub -r -t homeassistant/sensor/rock4se_noctua_tachometer_status/config -m \
'{"name":"Tachometer Status","unique_id":"rock4se_noctua_tachometer_status","state_topic":"rock4se/noctua_fan/state","value_template":"{{ value_json.tachometer_status }}","icon":"mdi:speedometer","availability_topic":"rock4se/noctua_fan/availability","payload_available":"online","payload_not_available":"offline","device":{"identifiers":["rock4se_noctua_pwm_fan"],"name":"ROCK 4SE Noctua PWM Fan","manufacturer":"Radxa / Noctua","model":"ROCK 4 SE + NF-A4x20 5V PWM"}}'
  mqtt_pub -r -t homeassistant/binary_sensor/rock4se_noctua_fan_controller/config -m \
'{"name":"Fan Controller","unique_id":"rock4se_noctua_fan_controller","state_topic":"rock4se/noctua_fan/state","value_template":"{{ value_json.status }}","payload_on":"ON","payload_off":"OFF","device_class":"running","availability_topic":"rock4se/noctua_fan/availability","payload_available":"online","payload_not_available":"offline","device":{"identifiers":["rock4se_noctua_pwm_fan"],"name":"ROCK 4SE Noctua PWM Fan","manufacturer":"Radxa","model":"ROCK 4 SE"}}'
}

shutdown() {
  [ -n "${TACH_PID:-}" ] && kill "$TACH_PID" 2>/dev/null || true
  mqtt_pub -r -t "$AVAILABILITY_TOPIC" -m offline 2>/dev/null || true
  exit 0
}
trap shutdown INT TERM

[ -r /dev/mem ] && [ -w /dev/mem ] || {
  log "FATAL: /dev/mem not available read/write"
  exit 1
}

TEMP_FILE=""
for z in /sys/class/thermal/thermal_zone*; do
  [ -r "$z/temp" ] || continue
  t="$(cat "$z/type" 2>/dev/null || true)"
  case "$t" in
    *soc*|*cpu*|*package*)
      TEMP_FILE="$z/temp"
      break
      ;;
  esac
done

[ -n "$TEMP_FILE" ] || {
  log "FATAL: No thermal sensor found"
  exit 1
}

TEMP_TYPE="$(cat "$(dirname "$TEMP_FILE")/type" 2>/dev/null || echo unknown)"

# Initializes PWM on cold boot if registers are zero, then sets fail-safe max.
INIT_RESULT="$(rock4se-pwmctl 100)"
log "PWM initialization: $INIT_RESULT"

publish_discovery
mqtt_pub -r -t "$AVAILABILITY_TOPIC" -m online

log "Temperature sensor: $TEMP_TYPE"
log "Temperature file: $TEMP_FILE"
log "MQTT: $MQTT_HOST:$MQTT_PORT"
log "PWM access: /dev/mem with verified cold-start initialization"

[ -c /dev/gpiochip2 ] || {
  log "FATAL: /dev/gpiochip2 is not available; cannot read physical pin 3"
  exit 1
}

rm -f /run/noctua_tach.json
TACH_WINDOW_SECONDS="$TACH_WINDOW_SECONDS" \
  TACH_GPIO_CHIP=/dev/gpiochip2 \
  TACH_GPIO_LINE=7 \
  TACH_PULSES_PER_REVOLUTION=2 \
  tachometer.py &
TACH_PID=$!

sleep 1
if ! kill -0 "$TACH_PID" 2>/dev/null; then
  log "FATAL: Tachometer process failed to start"
  exit 1
fi
log "Tachometer: physical pin 3, GPIO2_A7, /dev/gpiochip2 line 7"
log "Tachometer pull-up: onboard 4.7 kOhm to 3.0 V"
log "Tachometer pulse rate: 2 pulses per revolution"

LAST_SPEED=-1
LAST_RPM=-1

while true; do
  RAW="$(cat "$TEMP_FILE" 2>/dev/null || echo 0)"

  case "$RAW" in
    ''|*[!0-9-]*)
      log "WARNING: Invalid temperature '$RAW'; setting maximum speed"
      rock4se-pwmctl 100 >/dev/null
      sleep "$POLL_SECONDS"
      continue
      ;;
  esac

  if [ "$RAW" -gt 1000 ]; then
    TEMP=$((RAW / 1000))
  else
    TEMP="$RAW"
  fi

  if [ "$TEMP" -lt 40 ]; then SPEED=25
  elif [ "$TEMP" -lt 50 ]; then SPEED=35
  elif [ "$TEMP" -lt 60 ]; then SPEED=50
  elif [ "$TEMP" -lt 70 ]; then SPEED=70
  elif [ "$TEMP" -lt 80 ]; then SPEED=85
  else SPEED=100
  fi

  [ "$SPEED" -ge "$MIN_SPEED" ] || SPEED="$MIN_SPEED"

  RESULT="$(rock4se-pwmctl "$SPEED")"
  DUTY="$(printf '%s\n' "$RESULT" | sed -n 's/.* duty=\([0-9][0-9]*\).*/\1/p')"

  if [ "$SPEED" -ne "$LAST_SPEED" ]; then
    log "CPU ${TEMP}°C -> fan ${SPEED}% -> register duty ${DUTY}"
    LAST_SPEED="$SPEED"
  fi

  RPM=0
  TACH_STATUS="STARTING"
  if [ -r /run/noctua_tach.json ]; then
    RPM="$(sed -n 's/.*"rpm":\([0-9][0-9]*\).*/\1/p' /run/noctua_tach.json | head -1)"
    TACH_STATUS="$(sed -n 's/.*"status":"\([A-Z][A-Z]*\)".*/\1/p' /run/noctua_tach.json | head -1)"
    RPM="${RPM:-0}"
    TACH_STATUS="${TACH_STATUS:-ERROR}"
  fi

  if [ "$RPM" -ne "$LAST_RPM" ]; then
    log "Fan tachometer: ${RPM} RPM (${TACH_STATUS})"
    LAST_RPM="$RPM"
  fi

  mqtt_pub -t "$STATE_TOPIC" -m \
    "{\"temperature\":$TEMP,\"speed\":$SPEED,\"duty_cycle\":$DUTY,\"rpm\":$RPM,\"tachometer_status\":\"$TACH_STATUS\",\"status\":\"ON\"}"
  mqtt_pub -r -t "$AVAILABILITY_TOPIC" -m online

  sleep "$POLL_SECONDS"
done
