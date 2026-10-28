"""
Proves that the guardrails actually fire.

A green test suite shows that nothing is wrong today. It does not show that the
tests would notice if something were. So each defect this project is built to
prevent is available as an injectable variable, and this script puts them in one
at a time and reports which assertions caught them.

Every defect below is a real failure mode: three were shipped to production in
the system this is modelled on, and the fourth is the one that nearly was.

Run:  python scripts/prove_guardrails.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "target" / "run_results.json"

DEFECTS = {
    "ramp_ceiling": (
        "Ramping sellers capped at the 100-109.99% band, so the ones doing "
        "best are quietly underpaid."
    ),
    "commission_on_gross": (
        "Commission paid on gross instead of net, so refunded sales are paid "
        "for."
    ),
    "override_without_reason": (
        "A manual attainment override with the justification removed: the "
        "number survives, the explanation does not."
    ),
    "overlapping_periods": (
        "Two team-membership intervals covering the same day, so the same "
        "revenue counts for two teams and two leaders are paid for it."
    ),
}


def run(defect: str) -> list[str]:
    env = {**os.environ, "DBT_PROFILES_DIR": str(ROOT)}
    args = ["--vars", json.dumps({"inject_defect": defect})] if defect else []

    subprocess.run(["dbt", "run", *args], cwd=ROOT, env=env, capture_output=True)
    subprocess.run(["dbt", "test", *args], cwd=ROOT, env=env, capture_output=True)

    results = json.loads(RESULTS.read_text())
    return sorted(
        r["unique_id"].split(".")[-1]
        for r in results["results"]
        if r["status"] == "fail"
    )


def main() -> None:
    print("baseline, no defect injected")
    baseline = run("")
    if baseline:
        print("  unexpected failures in the clean run:")
        for name in baseline:
            print(f"    {name}")
        raise SystemExit(1)
    print("  all assertions pass\n")

    width = max(len(d) for d in DEFECTS)
    uncaught = []

    for defect, description in DEFECTS.items():
        caught = run(defect)
        mark = "caught" if caught else "NOT CAUGHT"
        print(f"{defect:<{width}}  {mark}")
        print(f"{'':<{width}}  {description}")
        for name in caught:
            print(f"{'':<{width}}    -> {name}")
        if not caught:
            uncaught.append(defect)
        print()

    run("")  # leave the warehouse in its clean state

    if uncaught:
        print(f"{len(uncaught)} defect(s) went undetected: {', '.join(uncaught)}")
        raise SystemExit(1)

    print(f"all {len(DEFECTS)} defects detected")


if __name__ == "__main__":
    main()
