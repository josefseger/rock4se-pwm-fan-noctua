#!/usr/bin/env python3
"""Read Noctua fan tach pulses from ROCK 4 SE physical pin 3.

Physical pin 3 is RK3399 GPIO2_A7: gpiochip2 line offset 7.
Noctua PWM fans emit two tachometer pulses per revolution.
"""

from __future__ import annotations

import json
import os
import signal
import sys
import time
from pathlib import Path

import gpiod
from gpiod.line import Bias, Direction, Edge

GPIO_CHIP = os.environ.get("TACH_GPIO_CHIP", "/dev/gpiochip2")
GPIO_LINE = int(os.environ.get("TACH_GPIO_LINE", "7"))
PULSES_PER_REVOLUTION = int(os.environ.get("TACH_PULSES_PER_REVOLUTION", "2"))
WINDOW_SECONDS = float(os.environ.get("TACH_WINDOW_SECONDS", "2.0"))
OUTPUT_FILE = Path(os.environ.get("TACH_OUTPUT_FILE", "/run/noctua_tach.json"))

running = True


def stop(_signum: int, _frame: object) -> None:
    global running
    running = False


def atomic_write(payload: dict[str, object]) -> None:
    temp = OUTPUT_FILE.with_suffix(".tmp")
    temp.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    temp.replace(OUTPUT_FILE)


def main() -> int:
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    settings = gpiod.LineSettings(
        direction=Direction.INPUT,
        edge_detection=Edge.FALLING,
        # Preserve the ROCK 4 SE board's external 4.7 kOhm pull-up to 3.0 V.
        bias=Bias.AS_IS,
    )

    try:
        request = gpiod.request_lines(
            GPIO_CHIP,
            consumer="rock4se-noctua-tach",
            config={GPIO_LINE: settings},
            event_buffer_size=256,
        )
    except Exception as exc:  # hardware/runtime error
        atomic_write({"rpm": 0, "pulses": 0, "status": "ERROR", "error": str(exc)})
        print(f"Tachometer error: {exc}", file=sys.stderr, flush=True)
        return 1

    print(
        f"Tachometer active: {GPIO_CHIP} line {GPIO_LINE}, "
        f"{PULSES_PER_REVOLUTION} pulses/revolution, {WINDOW_SECONDS:.1f}s window",
        flush=True,
    )

    try:
        while running:
            started = time.monotonic()
            deadline = started + WINDOW_SECONDS
            pulses = 0

            while running:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                if request.wait_edge_events(timeout=min(remaining, 0.5)):
                    pulses += len(request.read_edge_events())

            elapsed = max(time.monotonic() - started, 0.001)
            rpm = round((pulses * 60.0) / (PULSES_PER_REVOLUTION * elapsed))
            atomic_write(
                {
                    "rpm": rpm,
                    "pulses": pulses,
                    "status": "OK",
                    "window_seconds": round(elapsed, 3),
                }
            )
    except Exception as exc:
        atomic_write({"rpm": 0, "pulses": 0, "status": "ERROR", "error": str(exc)})
        print(f"Tachometer runtime error: {exc}", file=sys.stderr, flush=True)
        return 1
    finally:
        request.release()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
