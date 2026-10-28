{% snapshot snap_payroll %}

{{
    config(
        unique_key = "payroll_key",
        strategy = "check",
        check_cols = ["commission_total", "amount_payable", "attainment_applied", "gross_amount", "net_amount"],
        invalidate_hard_deletes = true
    )
}}

-- What was paid, frozen at the moment it was paid.
--
-- The source system is a photograph of the present. When a seller leaves, their
-- historical transactions can disappear retroactively; when a refund lands in
-- November it changes what October looks like. Re-running a closed month does
-- not reproduce the closed month -- it produces today's answer to a question
-- that was settled weeks ago.
--
-- That is survivable for a dashboard and not survivable for payroll. An audit
-- in six months asks what this person was paid and why, and "re-run it and see"
-- is not an answer when the inputs have moved underneath.
--
-- So the close ends by snapshotting the payout. The snapshot is append-only:
-- a later change to the same period writes a NEW row with its own validity
-- window, and the row that was actually paid stays exactly as it was. The
-- difference between the two is then visible, which is the point -- an
-- adjustment can be settled in the following month, deliberately, instead of
-- being discovered by accident.
--
-- scripts/prove_point_in_time.py demonstrates this end to end.

select
    period_label || '|' || seller_email as payroll_key,
    period_label,
    seller_email,
    display_name,
    team,
    rule_code,
    monthly_target,
    gross_amount,
    net_amount,
    attainment_computed,
    attainment_applied,
    manual_override_reason,
    tier_floor,
    commission_total,
    amount_payable,
    payout_note
from {{ ref('fct_seller_commission') }}

{% endsnapshot %}
