-- The payout table. Editing commission rates is a data change, not a code
-- change: nothing downstream hardcodes a percentage.

select
    cast(min_attainment as decimal(8,4)) as min_attainment,
    cast(pct_full       as decimal(6,4)) as pct_full,
    cast(pct_recurring  as decimal(6,4)) as pct_recurring
from {{ ref('raw_commission_tiers') }}
