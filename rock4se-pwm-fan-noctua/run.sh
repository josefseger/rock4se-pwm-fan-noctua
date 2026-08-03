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
MQTT_HOST="$(json_string mqtt_host)"
MQTT_PORT="$(json_number mqtt_port)"
MQTT_USER="$(json_string mqtt_user)"
MQTT_PASSWORD="$(json_string mqtt_password)"

POLL_SECONDS="${POLL_SECONDS:-5}"
MIN_SPEED="${MIN_SPEED:-25}"
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
  mqtt_pub -r -t homeassistant/binary_sensor/rock4se_noctua_fan_controller/config -m \
'{"name":"Fan Controller","unique_id":"rock4se_noctua_fan_controller","state_topic":"rock4se/noctua_fan/state","value_template":"{{ value_json.status }}","payload_on":"ON","payload_off":"OFF","device_class":"running","availability_topic":"rock4se/noctua_fan/availability","payload_available":"online","payload_not_available":"offline","device":{"identifiers":["rock4se_noctua_pwm_fan"],"name":"ROCK 4SE Noctua PWM Fan","manufacturer":"Radxa","model":"ROCK 4 SE"}}'
}

shutdown() {
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

LAST_SPEED=-1

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

  mqtt_pub -t "$STATE_TOPIC" -m \
    "{\"temperature\":$TEMP,\"speed\":$SPEED,\"duty_cycle\":$DUTY,\"status\":\"ON\"}"
  mqtt_pub -r -t "$AVAILABILITY_TOPIC" -m online

  sleep "$POLL_SECONDS"
done
