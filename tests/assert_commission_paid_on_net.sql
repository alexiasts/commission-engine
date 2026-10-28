-- Commission is paid on NET revenue -- what the company actually collected.
--
-- Paying on gross means paying for sales that were refunded. It is a one-word
-- change in a model and it never looks wrong in a total, which is exactly why
-- it needs an assertion rather than a review.

select
    seller_email,
    display_name,
    net_full,
    pct_full,
    commission_full,
    cast(net_full * pct_full as decimal(12,2)) as commission_full_expected,
    net_recurring,
    pct_recurring,
    commission_recurring,
    cast(net_recurring * pct_recurring as decimal(12,2)) as commission_recurring_expected
from {{ ref('fct_seller_commission') }}
where abs(commission_full - cast(net_full * pct_full as decimal(12,2))) > 0.01
   or abs(commission_recurring - cast(net_recurring * pct_recurring as decimal(12,2))) > 0.01
