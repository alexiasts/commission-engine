{{ config(severity = 'warn', warn_if = '>0') }}

-- OPEN QUESTION, surfaced every run until it is settled. See
-- docs/02-churn-vs-refund.md.
--
-- Severity is `warn` on purpose. This is not a defect to fix in SQL -- both
-- readings are correctly implemented -- it is a definition the business has not
-- yet chosen between. Failing the build would train people to ignore a red
-- pipeline; passing in silence would let a known, priced ambiguity quietly
-- become permanent. A warning on every run is the honest middle: it keeps the
-- number in front of whoever runs the close, and it stops being noise the day
-- someone answers the question.

select
    seller_email,
    display_name,
    disputed_transactions,
    net_difference,
    commission_difference
from {{ ref('rpt_cancellation_reconciliation') }}
where abs(commission_difference) > 0.01
