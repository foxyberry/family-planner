#!/usr/bin/env python3
"""The agent driver's client (ios/Journeys/Tests/Driver/PROTOCOL.md), standard library only.

  python3 tools/driver/fp-driver.py ls
  python3 tools/driver/fp-driver.py do home.clockHeld
  python3 tools/driver/fp-driver.py do addChild.nameChanged '{"text": "Kid C"}'
  python3 tools/driver/fp-driver.py run ios/Journeys/Tests/Driver/journeys/add-a-child.json

The app must already run with -fpDriver (make run ... DRIVER=1) in the journey's world; `run` prints
the launch flags a journey needs and checks only what the app shows. It talks to 127.0.0.1:8790 (on a
simulator the app shares this Mac's loopback). Exit code: 0 = done, 1 = a refusal or a failed expect.
"""
import json
import sys
import time
import urllib.error
import urllib.request

URL = "http://127.0.0.1:8790"
WAIT_SECONDS = 5


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(URL + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        return json.loads(error.read() or b"{}")
    except urllib.error.URLError as error:
        sys.exit(f"fp-driver: no driver at {URL} ({error.reason}); start the app with -fpDriver (make run DRIVER=1)")


def ls():
    return call("GET", "/ls")


def wait_for_driver(seconds=30):
    """The app may still be launching (or relaunching over USB): wait until `ls` answers."""
    deadline = time.monotonic() + seconds
    while True:
        try:
            with urllib.request.urlopen(URL + "/ls", timeout=3) as response:
                return json.loads(response.read() or b"{}")
        except (urllib.error.URLError, ConnectionError, OSError):
            if time.monotonic() > deadline:
                sys.exit(f"fp-driver: no driver at {URL} after {seconds} s; start the app with -fpDriver")
            time.sleep(0.5)


def do(action, args=None):
    return call("POST", "/do", {"action": action, "args": args or {}})


def shown(view, key):
    if key == "screen":
        return view.get("screen")
    if key in view.get("fields", {}):
        return view["fields"][key]
    return view.get("app", {}).get(key)


def run(path):
    journey = json.load(open(path, encoding="utf-8"))
    world = journey.get("world", {})
    print(f"journey: {journey.get('journey')}")
    print("world (start the app with): -fpNow {now} -fpFamily {family}{skip} -fpDriver".format(
        now=world.get("now", "?"), family=world.get("family", "?"),
        skip=" -fpSkipFaceID" if world.get("faceID") == "success" else ""))
    view = wait_for_driver()
    for number, step in enumerate(journey.get("steps", []), 1):
        if "do" in step:
            args = {key: (view.get("fields", {}).get(value[1:]) if isinstance(value, str) and value.startswith("$") else value)
                    for key, value in step.get("args", {}).items()}
            view = do(step["do"], args)
            if "error" in view:
                print(f"step {number}: {step['do']} refused: {view['error']}")
                return 1
            print(f"step {number}: did {step['do']}")
        elif "expect" in step:
            deadline = time.monotonic() + WAIT_SECONDS
            while True:
                view = ls()
                wrong = {key: shown(view, key) for key, value in step["expect"].items() if shown(view, key) != value}
                if not wrong:
                    print(f"step {number}: saw {json.dumps(step['expect'])}")
                    break
                if time.monotonic() > deadline:
                    print(f"step {number}: expected {json.dumps(step['expect'])}, saw {json.dumps(wrong)} on {view.get('screen')}")
                    return 1
                time.sleep(0.2)
    print("journey passed")
    return 0


def main(argv):
    if len(argv) >= 2 and argv[1] == "ls":
        print(json.dumps(ls(), indent=2, sort_keys=True))
        return 0
    if len(argv) >= 3 and argv[1] == "do":
        result = do(argv[2], json.loads(argv[3]) if len(argv) > 3 else {})
        print(json.dumps(result, indent=2, sort_keys=True))
        return 1 if "error" in result else 0
    if len(argv) == 3 and argv[1] == "run":
        return run(argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
