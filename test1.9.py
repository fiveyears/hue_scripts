#!/usr/bin/env python3
import argparse
import logging

import signal, os

INT_COUNT = 0
def _sigint_handler(sig, frame):
    global INT_COUNT
    INT_COUNT += 1
    if INT_COUNT >= 2:
        print("Force exit via second Ctrl-C")
        os._exit(1)
    else:
        print("Graceful stop requested (first Ctrl-C)")
        try:
            stop_event.set()
        except Exception:
            pass

signal.signal(signal.SIGINT, _sigint_handler)
import math
import sys
import threading
import time
import warnings

import requests
from hue_entertainment_pykit import (
    setup_logs,
    create_bridge,
    Entertainment,
    Streaming,
)

# ========= USER CONFIG =========

BRIDGE_IP = "192.168.2.50"
USERNAME = "9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk"  # v2 appkey
CLIENTKEY = "8FF5BC23AA57441B555C594F0FFDDB86"        # clientkey (hex)

# These are what you used before with hue_entertainment_pykit
IDENTIFICATION = "BRIDGE_RID"
BRIDGE_RID = "0de2b3b8-c864-4e3f-ba52-d157ccb1f9c8"
SWVERSION = 1962097030
HUE_APP_ID = "guestbathstreamer"

# 7 entertainment light RIDs mapped to indices 0..6
LIGHT_RIDS = [
    "7198eeef-0c04-4232-942a-902c67183b53",  # index 0
    "4b19ef2f-6935-45be-b79c-836f23b548e2",  # index 1
    "83bcf837-6422-4417-8751-250e5b5f7842",  # index 2
    "28ad7b0a-5ed6-40da-928a-357fd3240221",  # index 3
    "cf6b19b5-44d0-475c-b769-1d9a37c32b78",  # index 4
    "d55fd8e6-94b5-427e-952f-df14946e14e4",  # index 5
    "959974e8-fbc6-4555-91ce-3af37e555855",  # index 6
]

NUM_LIGHTS = len(LIGHT_RIDS)

# ===============================


def velocity_to_period(velocity: int) -> float:
    """
    Map velocity 0..100 to a rainbow period in seconds.
    0   -> very slow (~40s per full cycle)
    100 -> very fast (~4s per full cycle)
    """
    v = max(0, min(100, velocity))
    max_period = 40.0
    min_period = 4.0
    return max_period - (max_period - min_period) * (v / 100.0)


def hsv_to_rgb(h: float, s: float, v: float):
    """
    Simple HSV -> RGB, h,s,v in [0,1], return r,g,b in [0,1].
    """
    if s == 0.0:
        return v, v, v
    i = int(h * 6.0)
    f = (h * 6.0) - i
    i = i % 6
    p = v * (1.0 - s)
    q = v * (1.0 - s * f)
    t = v * (1.0 - s * (1.0 - f))
    if i == 0:
        r, g, b = v, t, p
    elif i == 1:
        r, g, b = q, v, p
    elif i == 2:
        r, g, b = p, v, t
    elif i == 3:
        r, g, b = p, q, v
    elif i == 4:
        r, g, b = t, p, v
    else:
        r, g, b = v, p, q
    return r, g, b


def compute_color(light_index: int,
                  t: float,
                  num_lights: int,
                  period: float,
                  simultaneous: bool,
                  extend: bool):
    """
    Compute a smooth RGB color for a given light at time t.
    - simultaneous=False: rainbow wave across lights
    - simultaneous=True: all lights same color
    - extend=True: add very bright white pulses and dark violet dips
    """
    # Base hue evolution over time
    base_phase = t / period  # cycles per period
    if simultaneous:
        phase = base_phase
    else:
        # Offset each light around the color wheel
        phase = base_phase + (light_index / max(1, num_lights))

    hue = phase % 1.0

    # Base saturation & value
    s = 1.0
    v = 0.8

    if extend:
        # White pulse over time
        white_pulse = 0.5 * (1.0 + math.sin(2.0 * math.pi * (t / (period * 2.0))))
        # Extra brightness from white pulse (up to +0.3)
        v += 0.3 * white_pulse

        # Dark violet dip around hue ~0.77
        violet_center = 0.77
        violet_width = 0.07
        dist = (min(abs(hue - violet_center),
                    1.0 - abs(hue - violet_center)) / violet_width)
        violet_factor = math.exp(-dist * dist)
        v -= 0.5 * violet_factor  # strong dimming in that band

        v = max(0.05, min(1.0, v))
    else:
        # Subtle slow breathing in brightness even without extend
        v_base = 0.7
        v_breath = 0.1 * math.sin(2.0 * math.pi * (t / (period * 3.0)))
        v = max(0.1, min(1.0, v_base + v_breath))

    r, g, b = hsv_to_rgb(hue, s, v)
    return int(r * 255), int(g * 255), int(b * 255)


def fetch_on_states():
    """
    Fetch on/off states for our 7 entertainment lights.
    Returns dict[rid] = bool(on).
    """
    url = f"https://{BRIDGE_IP}/clip/v2/resource/light"
    headers = {"hue-application-key": USERNAME}

    resp = requests.get(url, headers=headers, timeout=5, verify=False)
    resp.raise_for_status()
    payload = resp.json()

    states = {}
    for item in payload.get("data", []):
        rid = item.get("id")
        if rid in LIGHT_RIDS:
            on_state = item.get("on", {}).get("on", False)
            states[rid] = bool(on_state)
    return states


def monitor_onoff(stop_event: threading.Event, initial_states: dict):
    """
    Polls the light resources and stops the animation if any of the tracked
    lights changes its on/off state compared to initial_states.
    """
    log = logging.getLogger("onoff-monitor")
    log.info("Starting on/off monitor thread")

    while not stop_event.is_set():
        try:
            current = fetch_on_states()
            for rid, initial_on in initial_states.items():
                current_on = current.get(rid, initial_on)
                if current_on != initial_on:
                    log.info(
                        "Detected on/off change for light %s: %s -> %s. Stopping.",
                        rid,
                        initial_on,
                        current_on,
                    )
                    stop_event.set()
                    return
        except Exception as e:
            log.warning("Error while polling light states: %s", e)

        # Poll about once per second
        time.sleep(1.0)

    log.info("On/off monitor thread exiting due to stop_event")


def run_rainbow_loop(streaming: Streaming,
                     period: float,
                     simultaneous: bool,
                     extend: bool,
                     stop_event: threading.Event):
    """
    Main infinite rainbow loop. Runs until stop_event is set.
    """
    log = logging.getLogger("rainbow")
    log.info(
        "Starting rainbow loop: period=%.2fs, simultaneous=%s, extend=%s",
        period,
        simultaneous,
        extend,
    )

    streaming.set_color_space("rgb")

    frame_interval = 1.0 / 60.0  # 60 FPS target
    start = time.monotonic()

    try:
        while not stop_event.is_set():
            now = time.monotonic()
            t = now - start

            for idx in range(NUM_LIGHTS):
                r, g, b = compute_color(
                    light_index=idx,
                    t=t,
                    num_lights=NUM_LIGHTS,
                    period=period,
                    simultaneous=simultaneous,
                    extend=extend,
                )
                streaming.set_input((r, g, b, idx))

            # Maintain roughly constant frame rate
            frame_end = time.monotonic()
            sleep_time = frame_interval - (frame_end - now)
            if sleep_time > 0:
                time.sleep(sleep_time)
    except KeyboardInterrupt:
        log.info("KeyboardInterrupt received, stopping rainbow loop")
        stop_event.set()
    finally:
        log.info("Rainbow loop exiting")


def main():
    parser = argparse.ArgumentParser(
        description="Hue Entertainment rainbow wave for Guestbath (7 spots)."
    )
    parser.add_argument(
        "-v", "--velocity",
        type=int,
        default=50,
        help="speed 0 (very slow) .. 100 (very fast); controls rainbow period",
    )
    parser.add_argument(
        "-s", "--simultaneous",
        action="store_true",
        help="animate all lights together instead of a wave",
    )
    parser.add_argument(
        "-e", "--extend",
        action="store_true",
        help="extend colors with bright white pulses and dark violet dips",
    )
    parser.add_argument(
        "--log-file",
        help="optional log file; if omitted, logs go to stdout",
    )
    parser.add_argument(
        "-V", "--verbose",
        action="count",
        default=0,
        help="Increase verbosity: -V = INFO, -VV = DEBUG"
    )
    args = parser.parse_args()
    # Set logging level
    if args.verbose == 1:
        logging.basicConfig(level=logging.INFO)
    elif args.verbose >= 2:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.WARNING)


    # Set up logging
    log_level = logging.INFO
    handlers = []


    if args.log_file:
        handlers.append(logging.FileHandler(args.log_file))
    else:
        handlers.append(logging.StreamHandler(sys.stdout))

    logging.basicConfig(
        level=log_level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=handlers,
    )

    # Also configure hue_entertainment_pykit logging
    setup_logs(level=log_level)

    # Silence urllib3 insecure warnings
    warnings.filterwarnings("ignore", category=requests.packages.urllib3.exceptions.InsecureRequestWarning)  # type: ignore[attr-defined]

    log = logging.getLogger("main")

    period = velocity_to_period(args.velocity)
    log.info(
        "Starting Guestbath entertainment: velocity=%d -> period=%.2fs, "
        "simultaneous=%s, extend=%s",
        args.velocity,
        period,
        args.simultaneous,
        args.extend,
    )

    # Build bridge model
    bridge = create_bridge(
        identification=IDENTIFICATION,
        rid=BRIDGE_RID,
        ip_address=BRIDGE_IP,
        swversion=SWVERSION,
        username=USERNAME,
        hue_app_id=HUE_APP_ID,
        clientkey=CLIENTKEY,
        name="My Bridge",
    )

    entertainment_service = Entertainment(bridge)

    log.info("Fetching entertainment configurations from bridge…")
    ent_configs = entertainment_service.get_entertainment_configs()
    if not ent_configs:
        log.error("No entertainment configurations found on the bridge.")
        sys.exit(1)

    # For now, just pick the first configuration (Guestbath)
    ent_conf = list(ent_configs.values())[0]
    log.info(
        "Using entertainment area: %s (id=%s)",
        ent_conf.name,
        ent_conf.id,
    )

    streaming = Streaming(
        bridge,
        ent_conf,
        entertainment_service.get_ent_conf_repo(),
    )

    # Get initial on/off states for our 7 lights
    try:
        initial_states = fetch_on_states()
        log.info("Initial on/off states: %s", initial_states)
    except Exception as e:
        log.warning("Could not fetch initial light states: %s", e)
        initial_states = {rid: True for rid in LIGHT_RIDS}

    stop_event = threading.Event()

    # Start monitor thread
    monitor_thread = threading.Thread(
        target=monitor_onoff,
        args=(stop_event, initial_states),
        daemon=True,
    )
    monitor_thread.start()

    # Start entertainment streaming
    log.info("Starting entertainment streaming…")
    streaming.start_stream()

    try:
        run_rainbow_loop(
            streaming=streaming,
            period=period,
            simultaneous=args.simultaneous,
            extend=args.extend,
            stop_event=stop_event,
        )
    finally:
        log.info("Stopping entertainment streaming…")
        try:
            streaming.stop_stream()
        except Exception as e:
            log.warning("Error while stopping streaming: %s", e)

        stop_event.set()
        monitor_thread.join(timeout=2.0)
        log.info("Done.")


if __name__ == "__main__":
    main()