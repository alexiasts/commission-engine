"""
Deterministic generator for the synthetic seed data.

Everything here is fabricated. The *shape* of the data mirrors a real sales
commission ledger (one row per transaction, refund and churn tracked as
separate flags), but no real person, email, product or amount appears.

Run:  python scripts/generate_seeds.py
"""

from __future__ import annotations

import csv
import random
from datetime import date, timedelta
from pathlib import Path

SEEDS = Path(__file__).resolve().parents[1] / "seeds"
RNG = random.Random(20261028)

PERIOD_START = date(2026, 8, 1)
PERIOD_END = date(2026, 9, 30)

PRODUCTS = [
    ("Curso Intensivo 12m", 3200.00),
    ("Curso Regular 12m", 2400.00),
    ("Curso Regular 6m", 1450.00),
    ("Plano Conversacao", 890.00),
    ("Plano Kids 12m", 2650.00),
    ("Intercambio Prep", 4100.00),
]

# --------------------------------------------------------------------------
# Roster
# --------------------------------------------------------------------------
# rule:
#   ''           -> standard tier table, target required
#   'RAMP_UP'    -> new hire. 100% attainment is a FLOOR, not a ceiling.
#   'CS'         -> customer success. flat pct of net, no target.
#
# The three RAMP_UP sellers below are the regression cases for the tier bug:
# one above 120%, one inside the 110-119.99% band, one just over 100%.

ROSTER = [
    # email, name, team, leader, target, rule, fixed_pct, active
    ("ana.ribeiro",      "Ana Ribeiro",      "Kraken",    "Eduardo Prado",  165000, "",        None, "yes"),
    ("bruno.sarmento",   "Bruno Sarmento",   "Kraken",    "Eduardo Prado",  158000, "",        None, "yes"),
    ("carla.estevao",    "Carla Estevao",    "Kraken",    "Eduardo Prado",  142000, "",        None, "yes"),
    ("diego.matoso",     "Diego Matoso",     "Kraken",    "Eduardo Prado",  120000, "RAMP_UP", None, "yes"),
    ("elisa.quadros",    "Elisa Quadros",    "Megalodon", "Pedro Caldas",   171000, "",        None, "yes"),
    ("fabio.lencastre",  "Fabio Lencastre",  "Megalodon", "Pedro Caldas",   149000, "",        None, "yes"),
    ("gisele.amorim",    "Gisele Amorim",    "Megalodon", "Pedro Caldas",   133000, "RAMP_UP", None, "yes"),
    ("heitor.bastos",    "Heitor Bastos",    "Megalodon", "Pedro Caldas",   155000, "",        None, "yes"),
    ("ivone.capella",    "Ivone Capella",    "Netuno",    "Douglas Serra",  168000, "",        None, "no"),
    ("joel.tavares",     "Joel Tavares",     "Netuno",    "Douglas Serra",  146000, "",        None, "yes"),
    ("karen.docelim",    "Karen Docelim",    "Netuno",    "Douglas Serra",  127000, "RAMP_UP", None, "yes"),
    ("lucas.vergara",    "Lucas Vergara",    "Netuno",    "Douglas Serra",  152000, "",        None, "yes"),
    ("marina.espindola", "Marina Espindola", "Poseidon",  "Renata Figueira", 174000, "",       None, "yes"),
    ("nuno.barcellos",   "Nuno Barcellos",   "Poseidon",  "Renata Figueira", 139000, "",       None, "yes"),
    ("olivia.rezende",   "Olivia Rezende",   "Poseidon",  "Renata Figueira", 161000, "",       None, "yes"),
    ("paulo.quintela",   "Paulo Quintela",   "Poseidon",  "Renata Figueira", 144000, "",       None, "yes"),
    # Titan was dissolved on 2026-09-16. Its sellers moved to other teams.
    # Their September revenue splits across two teams, by sale date.
    # Left mid-period. Revenue still counts for the team; the person is not paid.
    ("rafael.condeixa",  "Rafael Condeixa",  "Kraken",    "Eduardo Prado",  137000, "",        None, "yes"),
    ("sofia.marchetti",  "Sofia Marchetti",  "Netuno",    "Douglas Serra",  131000, "",        None, "yes"),
    # Departure settled at 100% by agreement: see manual_attainment_* below.
    ("tomas.varanda",    "Tomas Varanda",    "Megalodon", "Pedro Caldas",   118000, "",        None, "yes"),
    # On leave the whole period. No sales at all -- the row still has to exist.
    ("wagner.toledo",    "Wagner Toledo",    "Poseidon",  "Renata Figueira", 126000, "",       None, "yes"),
    # Customer Success: flat rate on net, no target, sales not team-visible.
    ("ursula.penedo",    "Ursula Penedo",    "CS",        "Larissa Avelar", None,   "CS",      0.10, "yes"),
    ("vitor.sandim",     "Vitor Sandim",     "CS",        "Larissa Avelar", None,   "CS",      0.10, "yes"),
]

# Target attainment per seller, used to size the generated revenue.
# Values chosen so the tier boundaries all get exercised.
ATTAINMENT_PLAN = {
    "ana.ribeiro":      1.27,   # top tier
    "bruno.sarmento":   1.14,   # 110-119.99
    "carla.estevao":    1.02,   # 100-109.99
    "diego.matoso":     1.41,   # RAMP_UP above 120 -> must reach top tier
    "elisa.quadros":    0.93,
    "fabio.lencastre":  0.84,
    "gisele.amorim":    1.11,   # RAMP_UP inside 110-119.99 -> the regression case
    "heitor.bastos":    1.22,
    "ivone.capella":    0.71,
    "joel.tavares":     1.06,
    "karen.docelim":    1.03,   # RAMP_UP just above the floor
    "lucas.vergara":    0.47,   # below 50% -> zero
    "marina.espindola": 1.33,
    "nuno.barcellos":   0.88,
    "olivia.rezende":   0.96,
    "paulo.quintela":   1.18,
    "rafael.condeixa":  1.09,
    "sofia.marchetti":  0.99,   # just short of 100
    "tomas.varanda":    0.62,
    "wagner.toledo":    0.00,   # on leave
    "ursula.penedo":    None,
    "vitor.sandim":     None,
}

DOMAIN = "lumina-idiomas.example"


def emails() -> dict[str, str]:
    return {r[0]: f"{r[0]}@{DOMAIN}" for r in ROSTER}


def write(name: str, header: list[str], rows: list[list]) -> None:
    SEEDS.mkdir(parents=True, exist_ok=True)
    with open(SEEDS / f"{name}.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(rows)
    print(f"  seeds/{name}.csv  ({len(rows)} rows)")


def month_days(d: date) -> list[date]:
    out, cur = [], d.replace(day=1)
    while cur.month == d.month:
        out.append(cur)
        cur += timedelta(days=1)
    return out


def build_sales() -> list[list]:
    mail = emails()
    rows: list[list] = []
    tx = 700000

    for month_start in (date(2026, 8, 1), date(2026, 9, 1)):
        days = month_days(month_start)
        for key, name, team, leader, target, rule, fixed, active in ROSTER:
            if rule == "CS":
                # CS revenue is smaller and flagged team_visible = false upstream,
                # which is exactly why the legacy import used to drop it entirely.
                wanted = RNG.uniform(38000, 52000)
            else:
                plan = ATTAINMENT_PLAN[key]
                # August runs a little cooler than September for everyone.
                factor = plan * (0.94 if month_start.month == 8 else 1.0)
                wanted = target * factor

            produced = 0.0
            while produced < wanted:
                product, base = RNG.choice(PRODUCTS)
                amount = round(base * RNG.uniform(0.78, 1.18), 2)
                if produced + amount > wanted * 1.03 and produced > wanted * 0.9:
                    break
                sale_date = RNG.choice(days)
                sale_type = "RECURRING" if RNG.random() < 0.42 else "FULL"

                # Two independent lifecycle events:
                #   refunded -> money went back to the customer
                #   churned  -> contract was cancelled
                # A refund always implies a cancelled contract. The reverse is
                # not true, and that asymmetry is the whole reconciliation story.
                churned = RNG.random() < 0.055
                refunded = churned and RNG.random() < 0.62

                tx += 1
                rows.append([
                    f"TX{tx}",
                    sale_date.isoformat(),
                    mail[key],
                    product,
                    sale_type,
                    f"{amount:.2f}",
                    "true" if refunded else "false",
                    "true" if churned else "false",
                    "false" if rule == "CS" else "true",
                ])
                produced += amount

    rows.sort(key=lambda r: (r[1], r[0]))
    return rows


def main() -> None:
    mail = emails()
    print("writing seeds")

    write(
        "raw_sales_transactions",
        ["transaction_id", "sale_date", "seller_email", "product_name",
         "sale_type", "gross_amount", "is_refunded", "is_churned", "team_visible"],
        build_sales(),
    )

    write(
        "raw_seller_roster",
        ["seller_email", "display_name", "team", "leader_name", "monthly_target",
         "commission_rule", "fixed_pct", "is_active", "manual_attainment_pct",
         "manual_attainment_reason"],
        [
            [
                mail[key], name, team, leader,
                "" if target is None else f"{target:.2f}",
                rule,
                "" if fixed is None else f"{fixed:.4f}",
                active,
                # One documented exception: a departure paid at 100% by agreement.
                "1.0000" if key == "tomas.varanda" else "",
                ("Desligamento em 12/09 - 100% concedido em acordo de rescisao, "
                 "aprovado pela diretoria comercial") if key == "tomas.varanda" else "",
            ]
            for key, name, team, leader, target, rule, fixed, active in ROSTER
        ],
    )

    write(
        "raw_commission_tiers",
        ["min_attainment", "pct_full", "pct_recurring"],
        [["1.2000", "0.0600", "0.0300"],
         ["1.1000", "0.0500", "0.0250"],
         ["1.0000", "0.0400", "0.0200"],
         ["0.9000", "0.0300", "0.0150"],
         ["0.8000", "0.0200", "0.0100"],
         ["0.7000", "0.0100", "0.0050"],
         ["0.5000", "0.0050", "0.0025"],
         ["0.0000", "0.0000", "0.0000"]],
    )

    # Normally empty. One row per seller who changed team mid-month, covering
    # ONLY the old stretch; the rest of the month falls back to the roster.
    write(
        "raw_team_periods",
        ["seller_email", "team", "valid_from", "valid_to", "note"],
        [
            [mail["rafael.condeixa"], "Titan", "2026-09-01", "2026-09-16",
             "Titan dissolvido em 16/09"],
            [mail["sofia.marchetti"], "Titan", "2026-09-01", "2026-09-16",
             "Titan dissolvido em 16/09"],
            [mail["rafael.condeixa"], "Titan", "2026-08-01", "2026-08-31",
             "mes inteiro no Titan"],
            [mail["sofia.marchetti"], "Titan", "2026-08-01", "2026-08-31",
             "mes inteiro no Titan"],
        ],
    )

    write(
        "raw_leadership",
        ["leader_email", "leader_name", "role", "scope", "team_target"],
        [
            [f"eduardo.prado@{DOMAIN}",    "Eduardo Prado",   "TL",       "Kraken",    "602000.00"],
            [f"pedro.caldas@{DOMAIN}",     "Pedro Caldas",    "TL",       "Megalodon", "593000.00"],
            [f"douglas.serra@{DOMAIN}",    "Douglas Serra",   "TL",       "Netuno",    "593000.00"],
            [f"renata.figueira@{DOMAIN}",  "Renata Figueira", "TL",       "Poseidon",  "618000.00"],
            [f"larissa.avelar@{DOMAIN}",   "Larissa Avelar",  "TL_CS",    "CS",        ""],
            # The director is measured against the COMPANY target, which is not
            # the sum of the team targets. Using the sum understates attainment.
            [f"forest.anselmo@{DOMAIN}",   "Forest Anselmo",  "DIRECTOR", "ALL",       "2750000.00"],
        ],
    )

    write(
        "raw_leader_tiers",
        ["role", "min_attainment", "pct"],
        [["TL", "1.2000", "0.0120"],
         ["TL", "1.0000", "0.0100"],
         ["TL", "0.0000", "0.0080"],
         ["DIRECTOR", "1.2000", "0.0045"],
         ["DIRECTOR", "1.0000", "0.0035"],
         ["DIRECTOR", "0.9000", "0.0025"],
         ["DIRECTOR", "0.8000", "0.0020"],
         ["DIRECTOR", "0.5000", "0.0015"],
         ["DIRECTOR", "0.0000", "0.0000"],
         ["TL_CS", "0.0000", "0.1000"]],
    )

    print("done")


if __name__ == "__main__":
    main()
