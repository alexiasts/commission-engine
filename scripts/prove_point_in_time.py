"""
Demonstrates why a closed period is snapshotted instead of re-derived.

The scenario is one that actually happens: a seller leaves, and the upstream
system stops returning their historical transactions. Nothing was deleted on
purpose and no error is raised -- the source simply answers today's question.
Re-running the closed month after that produces a different, smaller number
than the one that was paid.

Sequence:

  1. close the period and snapshot the payroll
  2. simulate the retroactive loss (half of one seller's sales vanish upstream)
  3. re-run the models -- the fact table now disagrees with what was paid
  4. snapshot again, and show the paid row is still intact

Run:  python scripts/prove_point_in_time.py
"""

from __future__ import annotations

import csv
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "seeds" / "raw_sales_transactions.csv"
BACKUP = ROOT / "seeds" / ".raw_sales_transactions.backup.csv"
VICTIM = "carla.estevao@lumina-idiomas.example"
PERIOD_PREFIX = "2026-09"


def dbt(*args: str) -> None:
    result = subprocess.run(
        ["dbt", *args],
        cwd=ROOT,
        env={**__import__("os").environ, "DBT_PROFILES_DIR": str(ROOT)},
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stdout[-3000:], file=sys.stderr)
        raise SystemExit(f"dbt {' '.join(args)} failed")


def query(sql: str):
    import duckdb

    con = duckdb.connect(str(ROOT / "commission_engine.duckdb"), read_only=True)
    try:
        return con.sql(sql).fetchall()
    finally:
        con.close()


def drop_some_sales(share: float = 0.18) -> int:
    """Remove a slice of the victim's in-period transactions from the source."""
    rows = list(csv.reader(SEED.open(encoding="utf-8")))
    header, body = rows[0], rows[1:]
    mine = [
        i for i, r in enumerate(body)
        if r[2] == VICTIM and r[1].startswith(PERIOD_PREFIX)
    ]
    doomed = set(mine[: max(1, int(len(mine) * share))])
    kept = [r for i, r in enumerate(body) if i not in doomed]
    with SEED.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(kept)
    return len(doomed)


def main() -> None:
    print("1. closing the period and snapshotting payroll")
    dbt("seed")
    dbt("run")
    dbt("snapshot")

    paid = query(f"""
        select commission_total, gross_amount, attainment_applied, tier_floor
        from snap_payroll
        where seller_email = '{VICTIM}' and dbt_valid_to is null
    """)[0]
    print(f"   paid: R$ {paid[0]:,.2f}  "
          f"on gross R$ {paid[1]:,.2f}  "
          f"({paid[2]:.2%} attained, {paid[3]:.0%} tier)")

    print("\n2. upstream retroactively loses part of that seller's history")
    shutil.copy(SEED, BACKUP)
    try:
        n = drop_some_sales()
        print(f"   {n} transactions no longer returned by the source")

        print("\n3. re-running the models against the source as it is TODAY")
        dbt("seed")
        dbt("run")
        now = query(f"""
            select commission_total, gross_amount, attainment_applied, tier_floor
            from fct_seller_commission
            where seller_email = '{VICTIM}'
        """)[0]
        print(f"   recomputed: R$ {now[0]:,.2f}  "
              f"on gross R$ {now[1]:,.2f}  "
              f"({now[2]:.2%} attained, {now[3]:.0%} tier)")
        if now[3] != paid[3]:
            print(f"   the re-run drops them a whole band: "
                  f"{paid[3]:.0%} -> {now[3]:.0%}")
        print(f"   a re-run would now understate the payout by "
              f"R$ {paid[0] - now[0]:,.2f}")

        print("\n4. snapshotting again")
        dbt("snapshot")
        history = query(f"""
            select commission_total, dbt_valid_from, dbt_valid_to
            from snap_payroll
            where seller_email = '{VICTIM}'
            order by dbt_valid_from
        """)
        for amount, valid_from, valid_to in history:
            state = "superseded" if valid_to else "current"
            print(f"   R$ {amount:>10,.2f}   from {valid_from:%Y-%m-%d %H:%M}   {state}")

        print("\n   The figure that was paid is still on record, with the window")
        print("   it was true for. The adjustment is now a visible difference")
        print("   rather than a silent one.")

    finally:
        shutil.move(BACKUP, SEED)
        print("\n   (seed restored)")
        dbt("seed")
        dbt("run")


if __name__ == "__main__":
    main()
