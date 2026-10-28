{{ config(severity = 'warn') }}

-- Attainment above 200%, or a payout above 8% of the net it was computed from.
--
-- Neither is impossible. Both are, overwhelmingly, a target entered with a
-- missing digit. The check is cheap and it runs before anyone is paid.

select
    seller_email,
    display_name,
    monthly_target,
    gross_amount,
    attainment_applied,
    commission_total,
    case when net_amount > 0
         then cast(commission_total / net_amount as decimal(8,4)) end as commission_share_of_net
from {{ ref('fct_seller_commission') }}
-- CS pays a flat rate that sits above the 8% line by design, so the share
-- check does not apply to it.
where rule_code != 'CS'
  and (attainment_applied > 2.0
       or (net_amount > 0 and commission_total / net_amount > 0.08))
