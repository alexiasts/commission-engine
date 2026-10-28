-- Team-membership intervals must not overlap for the same seller.
--
-- Two intervals covering the same day means the same transaction is attributed
-- to two teams, so the revenue is counted twice and two leaders are paid for
-- it. Nothing downstream would complain: both team totals look reasonable on
-- their own.

select
    a.seller_email,
    a.team      as team_a,
    a.valid_from as from_a,
    a.valid_to   as to_a,
    b.team      as team_b,
    b.valid_from as from_b,
    b.valid_to   as to_b
from {{ ref('stg_team_periods') }} a
join {{ ref('stg_team_periods') }} b
    on a.seller_email = b.seller_email
   and (a.valid_from, a.team) < (b.valid_from, b.team)
   and a.valid_from <= b.valid_to
   and b.valid_from <= a.valid_to
