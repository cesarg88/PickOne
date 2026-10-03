#!/usr/bin/env python3
"""Verify an M7 -> M8 app replacement on a disposable simulator, without Files UI.

Uses the existing offline Home recovery scenario and its persistent test store.
See docs/engineering/validation/pilot-integration.md for builds and limitations.
"""

import argparse
import json
from pathlib import Path
import plistlib
import subprocess
import time


def simctl(*arguments):
    return subprocess.check_output(["xcrun", "simctl", *arguments], text=True).strip()


def preferences(container, bundle):
    path = container / "Library/Preferences" / f"{bundle}.plist"
    return plistlib.loads(path.read_bytes()) if path.exists() else {}


def await_schema(container, bundle, version):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        values = preferences(container, bundle)
        raw = values.get("ui_testing_home_recovery_viewer_state_active")
        if raw and json.loads(raw)["envelopeSchemaVersion"] == version:
            return values
        time.sleep(0.2)
    raise RuntimeError(f"App did not persist schema {version}; inspect its launch/crash logs")


def await_home_measurement(path, previous):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        data = path.read_bytes() if path.exists() else None
        if data and data != previous:
            state = json.loads(data)
            if any(101 in session.get("observedMovieIDs", []) for session in state["sessions"]):
                return data
        time.sleep(0.2)
    raise RuntimeError("Home did not persist a new lifecycle observation")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_app", type=Path)
    parser.add_argument("target_app", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--runtime", default="com.apple.CoreSimulator.SimRuntime.iOS-26-5")
    parser.add_argument("--device", default="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    apps = [args.source_app.resolve(), args.target_app.resolve()]
    bundles = [plistlib.loads((app / "Info.plist").read_bytes())["CFBundleIdentifier"] for app in apps]
    assert bundles[0] == bundles[1], "An update must use the same bundle identifier"
    bundle = bundles[0]
    simulator = simctl("create", "PickOne-Controlled-Upgrade", args.device, args.runtime)
    (args.output / "simulator-id.txt").write_text(simulator + "\n")
    arguments = ["-ui-testing", "-ui-testing-home-recovery", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    active_key = "ui_testing_home_recovery_viewer_state_active"
    previous_key = "ui_testing_home_recovery_viewer_state_previous"
    passed = False
    try:
        simctl("boot", simulator)
        simctl("bootstatus", simulator, "-b")
        simctl("install", simulator, str(apps[0]))
        simctl("launch", simulator, bundle, *arguments, "-ui-testing-home-recovery-reset")
        before_container = Path(simctl("get_app_container", simulator, bundle, "data"))
        before = await_schema(before_container, bundle, 3)
        simctl("terminate", simulator, bundle)
        original = before[active_key]
        source = json.loads(original)
        assert source["viewerProfileState"]["completedProfile"]["selectedProviderIDs"] == [8]
        assert {movie["movieID"] for movie in source["viewerMovieStates"]} == {303, 601}
        assert before["search_history"] == ["Sanitized Query"]
        (args.output / "m7-active.json").write_bytes(original)
        (args.output / "m7-previous.json").write_bytes(before[previous_key])

        # Replace the application; never uninstall, reset, or reseed its data.
        simctl("install", simulator, str(apps[1]))
        after_container = Path(simctl("get_app_container", simulator, bundle, "data"))
        # CoreSimulator may relocate the container during install; compare data, not its UUID path.
        assert preferences(after_container, bundle)[active_key] == original
        measurement_path = after_container / "Library/Application Support/PickOne/UITesting/ViewingDecisions/decisions.json"
        for phase in ["upgrade", "relaunch"]:
            prior_measurement = measurement_path.read_bytes() if measurement_path.exists() else None
            simctl("launch", simulator, bundle, *arguments)
            after = await_schema(after_container, bundle, 4)
            measurement = await_home_measurement(measurement_path, prior_measurement)
            simctl("terminate", simulator, bundle)
            migrated = json.loads(after[active_key])
            for key, value in source.items():
                if key != "envelopeSchemaVersion":
                    assert migrated[key] == value, f"{phase}: changed {key}"
            assert migrated["appliedConfirmationOperations"] == []
            assert all(movie.get("pickOneProvenance") is None for movie in migrated["viewerMovieStates"])
            assert after[previous_key] == original, "Lost exact pre-upgrade recovery bytes"
            assert after["search_history"] == before["search_history"]
            assert after["ui_testing_home_recovery_home_movie_id"] == before["ui_testing_home_recovery_home_movie_id"]
            (args.output / f"m8-{phase}.json").write_bytes(after[active_key])
            (args.output / f"measurement-{phase}.json").write_bytes(measurement)
        assert (args.output / "m8-upgrade.json").read_bytes() == (args.output / "m8-relaunch.json").read_bytes()
        result = {
            "result": "passed",
            "runtime": args.runtime,
            "device": args.device,
            "bundle": bundle,
            "preLaunchDataPreserved": True,
            "containerPathChanged": after_container != before_container,
            "sourceSchema": 3,
            "targetSchema": 4,
            "exactPreviousCopy": True,
            "stableAfterRelaunch": True,
            "fixture": "existing offline Home recovery scenario; synthetic data",
        }
        (args.output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result, indent=2))
        passed = True
    finally:
        simctl("shutdown", simulator)
        if passed:
            simctl("delete", simulator)
        else:
            print(f"Failed simulator retained for diagnosis: {simulator}")


if __name__ == "__main__":
    main()
