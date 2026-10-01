#!/usr/bin/env python3
"""
Hue Entertainment effects streamer v4.2

- Streams different effects over a Hue Entertainment area:
  - rainbow     (default)
  - stroboscope (rapid white flashes)
  - flashing    (slower white pulses)
  - bright      (static full-brightness white and exit)
- Rainbow can run as "wave" (per-light offset) or "simultaneous" mode
- Velocity 0..100 controls speed of the effect:
  - rainbow:     how fast the rainbow cycles
  - stroboscope: flash frequency
  - flashing:    pulse frequency
- Optional extended palette adds bright white and dark violet (rainbow only)
- Stops automatically if any light in the area is switched on/off
- Single Ctrl-C: graceful stop (stop streaming, stop monitoring)
- Second Ctrl-C: immediate exit
- Entertainment area is selected by NAME (e.g. "Guestbath", "TV room")
"""

import argparse
import logging
import math
import signal
import sys
import threading
import time
from typing import Dict, List, Set

import requests
import urllib3

from hue_entertainment_pykit import (
    setup_logs,
    create_bridge,
    Entertainment,
    Streaming,
)

# ------------- BRIDGE CONFIG (your working values) -----------------

BRIDGE_IP   = "192.168.2.50"  # your bridge IP

# v2 appkey and clientkey for this app
USERNAME    = "9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk"
CLIENTKEY   = "8FF5BC23AA57441B555C594F0FFDDB86"

IDENTIFICATION = "BRIDGE_RID"
BRIDGE_RID     = "0de2b3b8-c864-4e3f-ba52-d157ccb1f9c8"
SWVERSION      = 1962097030
HUE_APP_ID     = "guestbathstreamer"

# -------------------------------------------------------------------

# Disable HTTPS warnings for verify=False
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

log = logging.getLogger(__name__)

# Global flags / events for graceful + forced stop
stop_event = threading.Event()
hard_stop_event = threading.Event()
_ctrl_c_count = 0
_ctrl_c_lock = threading.Lock()


# ---------- Utilities ----------

def velocity_to_period(velocity: int) -> float:
    """
    Map velocity 0..100 to a full rainbow period in seconds.
    0  -> very slow  (40s per full cycle)
    100 -> very fast (3s per full cycle)
    """
    v = max(0, min(100, velocity))
    slow = 40.0
    fast = 3.0
    return slow - (slow - fast) * (v / 100.0)


def velocity_to_strobe_period(velocity: int) -> float:
    """
    Map velocity 0..100 to a stroboscope flash period (ON+OFF) in seconds.
    Faster at higher velocity.

    0   -> 0.5s  (2 Hz)
    100 -> 0.02s (~50 Hz)
    """
    v = max(0, min(100, velocity))
    slow = 0.5
    fast = 0.02
    return slow - (slow - fast) * (v / 100.0)


def velocity_to_flash_period(velocity: int) -> float:
    """
    Map velocity 0..100 to a slower flashing period (ON+OFF) in seconds.
    0   -> 3.0s
    100 -> 0.5s
    """
    v = max(0, min(100, velocity))
    slow = 3.0
    fast = 0.5
    return slow - (slow - fast) * (v / 100.0)


def hsv_to_rgb(h: float, s: float, v: float):
    """Convert HSV [0..1] to RGB 0..255."""
    h = h % 1.0
    i = int(h * 6.0)
    f = h * 6.0 - i
    p = v * (1.0 - s)
    q = v * (1.0 - f * s)
    t = v * (1.0 - (1.0 - f) * s)
    i = i % 6
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
    return int(r * 255), int(g * 255), int(b * 255)


def palette_color(phase: float, extend: bool) -> tuple[int, int, int]:
    """
    Smooth rainbow with optional extension:
    - Bright white peak
    - Dark violet dip

    phase: 0..1
    """
    # Quantize to 8192 steps
    steps = 8192
    phase = (round(phase * steps) % steps) / steps

    # Base rainbow
    v = 1.0
    s = 1.0

    # Extended effects
    bright_mix = 0.0
    dim_factor = 1.0

    if extend:
        # Bright white around phase ~0.15
        if 0.10 <= phase <= 0.20:
            # Triangular peak: 0 at 0.10/0.20, 1 at 0.15
            bright_mix = 1.0 - abs(phase - 0.15) / 0.05

        # Dark violet near end of cycle
        if 0.85 <= phase <= 1.0:
            # Dip down to ~20% brightness around 0.925
            dim_factor = 0.2 + 0.8 * abs(phase - 0.925) / 0.075
            dim_factor = max(0.2, min(1.0, dim_factor))

    v *= dim_factor
    r, g, b = hsv_to_rgb(phase, s, v)

    if extend and bright_mix > 0:
        # Mix in white
        r = int(r + bright_mix * (255 - r))
        g = int(g + bright_mix * (255 - g))
        b = int(b + bright_mix * (255 - b))

    return r, g, b


def fetch_entertainment_config_json(bridge_ip: str, appkey: str, ent_conf_id: str) -> dict:
    """Fetch raw v2 JSON for a single entertainment_configuration."""
    url = f"https://{bridge_ip}/clip/v2/resource/entertainment_configuration/{ent_conf_id}"
    headers = {"hue-application-key": appkey}
    resp = requests.get(url, headers=headers, timeout=5, verify=False)
    resp.raise_for_status()
    data = resp.json()
    if "data" not in data or not data["data"]:
        raise RuntimeError(f"No entertainment_configuration data for id {ent_conf_id}")
    return data["data"][0]


def fetch_light_states(bridge_ip: str, appkey: str, only_rids: Set[str]) -> Dict[str, bool]:
    """
    Return dict {light_rid: on_boolean} for the given RIDs.
    Uses /clip/v2/resource/light.
    """
    url = f"https://{bridge_ip}/clip/v2/resource/light"
    headers = {"hue-application-key": appkey}
    resp = requests.get(url, headers=headers, timeout=5, verify=False)
    resp.raise_for_status()
    data = resp.json().get("data", [])
    result: Dict[str, bool] = {}
    for item in data:
        rid = item.get("id")
        if rid in only_rids:
            on_state = item.get("on", {}).get("on", False)
            result[rid] = bool(on_state)
    return result


def monitor_onoff(
    bridge_ip: str,
    appkey: str,
    light_rids: Set[str],
    stop_evt: threading.Event,
):
    """
    Background thread:
    - Polls light on/off states for lights in the area
    - If any changes -> log and set stop_evt
    """
    log.debug("Monitor thread started with %d lights", len(light_rids))
    last_states: Dict[str, bool] | None = None

    while not stop_evt.is_set() and not hard_stop_event.is_set():
        try:
            states = fetch_light_states(bridge_ip, appkey, light_rids)
        except Exception as e:
            log.warning("Monitor: error while fetching light states: %s", e)
            time.sleep(0.5)
            continue

        if last_states is None:
            last_states = states
        else:
            if states != last_states:
                log.warning("Detected on/off change in watched lights -> stopping.")
                stop_evt.set()
                break

        time.sleep(0.3)

    log.debug("Monitor thread exiting.")


def run_rainbow_loop(
    streaming: Streaming,
    num_lights: int,
    period: float,
    simultaneous: bool,
    extend: bool,
    stop_evt: threading.Event,
):
    """
    Main rainbow animation loop. Runs until stop_evt or hard_stop_event is set.
    """
    log.info(
        "Rainbow loop: %d lights, period=%.2fs, mode=%s, extend=%s",
        num_lights,
        period,
        "simultaneous" if simultaneous else "wave",
        extend,
    )

    start_time = time.time()
    frame_interval = 0.02  # ~50fps

    while not stop_evt.is_set() and not hard_stop_event.is_set():
        now = time.time()
        base_phase = ((now - start_time) / period) % 1.0

        for idx in range(num_lights):
            if hard_stop_event.is_set():
                break

            if simultaneous:
                phase = base_phase
            else:
                # Wave: shift phase across lights
                phase = (base_phase + idx / num_lights) % 1.0

            r, g, b = palette_color(phase, extend)
            streaming.set_input((r, g, b, idx))

        # Keep frame rate roughly stable
        sleep_left = frame_interval - (time.time() - now)
        if sleep_left > 0:
            time.sleep(sleep_left)


def run_strobe_loop(
    streaming: Streaming,
    num_lights: int,
    period: float,
    stop_evt: threading.Event,
):
    """
    Stroboscope loop: all lights white on/off together.
    'period' is ON+OFF duration.
    """
    log.info(
        "Stroboscope loop: %d lights, period=%.4fs (%.2f Hz)",
        num_lights,
        period,
        1.0 / period if period > 0 else 0.0,
    )

    on = True
    half_period = max(0.001, period / 2.0)

    while not stop_evt.is_set() and not hard_stop_event.is_set():
        r = g = b = 255 if on else 0
        for idx in range(num_lights):
            if hard_stop_event.is_set():
                break
            streaming.set_input((r, g, b, idx))

        on = not on
        time.sleep(half_period)


def run_flashing_loop(
    streaming: Streaming,
    num_lights: int,
    period: float,
    stop_evt: threading.Event,
):
    """
    Slower flashing loop: all lights white on/off together.
    'period' is ON+OFF duration.
    """
    log.info(
        "Flashing loop: %d lights, period=%.4fs (%.2f Hz)",
        num_lights,
        period,
        1.0 / period if period > 0 else 0.0,
    )

    on = True
    half_period = max(0.01, period / 2.0)

    while not stop_evt.is_set() and not hard_stop_event.is_set():
        r = g = b = 255 if on else 0
        for idx in range(num_lights):
            if hard_stop_event.is_set():
                break
            streaming.set_input((r, g, b, idx))

        on = not on
        time.sleep(half_period)


def run_randombright_once(streaming: Streaming, num_lights: int):
    """
    Set each light to a random fully saturated color once and exit.
    A few frames ensure proper DTLS delivery.
    """
    log.info("RandomBright mode: random full-bright colors for %d lights.", num_lights)
    import random

    for _ in range(5):
        for idx in range(num_lights):
            h = random.random()
            r, g, b = hsv_to_rgb(h, 1.0, 1.0)
            streaming.set_input((r, g, b, idx))
        time.sleep(0.02)

def run_bright_once(
    streaming: Streaming,
    num_lights: int,
):
    """
    Set all lights to bright white, sending a few frames to ensure delivery.
    No long-running loop here.
    """
    log.info("Bright mode: setting all %d lights to full white once.", num_lights)
    r = g = b = 255

    # Send a few frames to make sure DTLS actually delivers it
    for _ in range(5):
        for idx in range(num_lights):
            streaming.set_input((r, g, b, idx))
        time.sleep(0.02)


# ---------- Signal handling ----------

def handle_sigint(signum, frame):
    global _ctrl_c_count
    with _ctrl_c_lock:
        _ctrl_c_count += 1
        if _ctrl_c_count == 1:
            log.warning("Caught Ctrl-C: requesting graceful stop…")
            stop_event.set()
        else:
            log.error("Second Ctrl-C: forcing immediate exit!")
            hard_stop_event.set()


# ---------- Area selection ----------

def choose_entertainment_area(ent_configs: dict, desired_name: str | None):
    """
    Given dict of ent_configs {id: config}, select by name (case-insensitive).
    If desired_name is None, prefer 'Guestbath' if present, otherwise the first.
    """
    if not ent_configs:
        raise RuntimeError("No entertainment configurations found on the bridge.")

    configs = list(ent_configs.values())
    if desired_name:
        dn = desired_name.lower()
        for conf in configs:
            if conf.name.lower() == dn:
                return conf
        # Not found -> error with list
        names = ", ".join(sorted(c.name for c in configs))
        raise RuntimeError(
            f"Entertainment area '{desired_name}' not found. Available: {names}"
        )

    # No name given -> choose by simple heuristic
    for conf in configs:
        if conf.name.lower() == "guestbath":
            return conf
    # else just first
    return configs[0]


def list_areas(ent_configs: dict):
    print("Available entertainment areas:")
    for conf in ent_configs.values():
        print(f"  - {conf.name} (id={conf.id})")


# ---------- Main ----------

def main():
    parser = argparse.ArgumentParser(
        description=(
            "Hue Entertainment effects streamer (area by name)\n\n"
            "Effects:\n"
            "  rainbow     Smooth continuous rainbow (default)\n"
            "  stroboscope Rapid white flashes (velocity = frequency)\n"
            "  flashing    Slower white pulses (velocity = pulse freq.)\n"
            "  bright      Static full-brightness white and exit\n"
            "\n"
            "Notes:\n"
            "  - --extend is valid only with --effect rainbow\n"
            "  - --simultaneous only affects rainbow\n"
            "  - Script stops if any watched light changes on/off\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-a",
        "--area",
        help="Name of entertainment area to use (e.g. 'Guestbath', 'TV room')",
    )
    parser.add_argument(
        "--list-areas",
        action="store_true",
        help="List available entertainment areas and exit",
    )
    parser.add_argument(
        "-s",
        "--simultaneous",
        action="store_true",
        help="Rainbow: all lights same color (no wave)",
    )
    parser.add_argument(
        "-e",
        "--extend",
        action="store_true",
        help="Rainbow: use extended palette (bright white + dark violet)",
    )
    parser.add_argument(
        "--effect",
        choices=["rainbow", "stroboscope", "flashing", "bright", "randombright"],
        default="rainbow",
        help=(
            "Effect to run. Choices: rainbow, stroboscope, flashing, bright, randombright. "
            "Default: rainbow"
        ),
    )
    parser.add_argument(
        "-V",
        "--verbose",
        action="count",
        default=0,
        help="Increase verbosity (once = INFO, twice = DEBUG)",
    )
    parser.add_argument(
        "-v",
        "--velocity",
        type=int,
        default=50,
        help=(
            "Velocity 0 (slow) .. 100 (fast). "
            "Rainbow: cycle speed; stroboscope/flashing: flash/pulse frequency. Default: 50"
        ),
    )
    parser.add_argument(
        "--log-file",
        help="Optional log file path (default: stderr)",
    )

    args = parser.parse_args()

    # Validate extend usage
    if args.extend and args.effect != "rainbow":
        parser.error("--extend is only valid with --effect rainbow")

    # Logging setup: WARNING by default
    handlers: List[logging.Handler] = []
    if args.log_file:
        handlers.append(logging.FileHandler(args.log_file))
    else:
        handlers.append(logging.StreamHandler(sys.stderr))

    level = logging.WARNING
    if args.verbose == 1:
        level = logging.INFO
    elif args.verbose >= 2:
        level = logging.DEBUG

    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=handlers,
    )

    # Also configure pykit internal logger similarly
    setup_logs(level=level)

    # Signals
    signal.signal(signal.SIGINT, handle_sigint)
    signal.signal(signal.SIGTERM, handle_sigint)

    log.info("Connecting to bridge %s", BRIDGE_IP)

    # Build bridge model for the library
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
    ent_configs = entertainment_service.get_entertainment_configs()

    if args.list_areas:
        list_areas(ent_configs)
        return

    ent_conf = choose_entertainment_area(ent_configs, args.area)
    print(f"Using entertainment area: {ent_conf.name} (id={ent_conf.id})")

    # Fetch raw v2 JSON for that area to discover channels + light_services
    try:
        raw_conf = fetch_entertainment_config_json(
            BRIDGE_IP,
            USERNAME,
            ent_conf.id,
        )
    except Exception as e:
        log.error("Failed to fetch entertainment_configuration JSON: %s", e)
        raise

    channels = raw_conf.get("channels", [])
    light_services = raw_conf.get("light_services", [])

    if not channels:
        raise RuntimeError("Selected entertainment area has no channels.")
    if not light_services:
        log.warning(
            "Selected entertainment area has no 'light_services' listed; "
            "on/off monitoring will be disabled."
        )

    num_lights = len(channels)
    # Light RIDs for monitoring
    light_rids: Set[str] = {ls.get("rid") for ls in light_services if "rid" in ls}

    log.info(
        "Area '%s': %d channels, %d light services",
        ent_conf.name,
        len(channels),
        len(light_rids),
    )

    # Start monitoring thread for long-running effects only
    monitor_thread: threading.Thread | None = None
    if light_rids and args.effect != "bright":
        monitor_thread = threading.Thread(
            target=monitor_onoff,
            args=(BRIDGE_IP, USERNAME, light_rids, stop_event),
            daemon=True,
        )
        monitor_thread.start()

    # Create streaming
    streaming = Streaming(
        bridge,
        ent_conf,
        entertainment_service.get_ent_conf_repo()
    )
    log.info("Starting entertainment streaming…")
    streaming.start_stream()

    try:
        effect = args.effect

        if effect == "rainbow":
            period = velocity_to_period(args.velocity)
            log.info("Effect: rainbow, velocity %d -> period %.2fs", args.velocity, period)
            run_rainbow_loop(
                streaming=streaming,
                num_lights=num_lights,
                period=period,
                simultaneous=args.simultaneous,
                extend=args.extend,
                stop_evt=stop_event,
            )

        elif effect == "stroboscope":
            if args.simultaneous:
                log.info("Effect 'stroboscope' always runs all lights together; --simultaneous is implied.")
            period = velocity_to_strobe_period(args.velocity)
            log.info(
                "Effect: stroboscope, velocity %d -> period %.4fs (~%.2f Hz)",
                args.velocity,
                period,
                1.0 / period if period > 0 else 0.0,
            )
            run_strobe_loop(
                streaming=streaming,
                num_lights=num_lights,
                period=period,
                stop_evt=stop_event,
            )

        elif effect == "flashing":
            if args.simultaneous:
                log.info("Effect 'flashing' always runs all lights together; --simultaneous is implied.")
            period = velocity_to_flash_period(args.velocity)
            log.info(
                "Effect: flashing, velocity %d -> period %.4fs (~%.2f Hz)",
                args.velocity,
                period,
                1.0 / period if period > 0 else 0.0,
            )
            run_flashing_loop(
                streaming=streaming,
                num_lights=num_lights,
                period=period,
                stop_evt=stop_event,
            )

        elif effect == "bright":
            if args.simultaneous:
                log.info("Effect 'bright' is static; --simultaneous has no effect.")
            log.info("Effect: bright (static full brightness, then exit)")
            run_bright_once(
                streaming=streaming,
                num_lights=num_lights,
            )
            # Tell the rest of the app we're done; finally block will clean up.
            stop_event.set()

        elif effect == "randombright":
            log.info("Effect: randombright (random full-bright colors, then exit)")
            run_randombright_once(streaming, num_lights)
            stop_event.set()

        else:
            # Should never happen due to argparse choices
            log.error("Unknown effect: %s", effect)
            stop_event.set()

    finally:
        log.info("Stopping entertainment streaming…")
        try:
            streaming.stop_stream()
        except Exception as e:
            log.warning("Error while stopping streaming: %s", e)

        stop_event.set()
        if monitor_thread is not None:
            monitor_thread.join(timeout=2.0)
        log.info("Done.")


if __name__ == "__main__":
    main()