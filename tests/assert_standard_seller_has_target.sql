-- A standard seller with no target is an error, not a zero.
--
-- Without this, a missing target divides into a null attainment, falls through
-- to the bottom tier, and pays R$ 0,00 -- for one person, or for everyone at
-- once, depending on where the blank came from. The failure is total and it
-- announces itself as a perfectly formatted report full of zeros.
--
-- RAMP_UP and CS are exempt by design: neither is measured against a target.

select
    seller_email,
    display_name,
    rule_code,
    monthly_target
from {{ ref('int_seller_month') }}
where rule_code = 'STANDARD'
  and (monthly_target is null or monthly_target <= 0)
