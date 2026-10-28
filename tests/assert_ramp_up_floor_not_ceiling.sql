-- REGRESSION GUARD: 100% is a floor for ramping sellers, never a ceiling.
--
-- The upstream mart pinned every seller flagged `em_rampagem` to the
-- 100-109.99% band whatever they actually attained. A new hire at 141% was paid
-- as though they had hit 100%. It was invisible for a month because the number
-- was plausible -- nobody expects a top performer's payout to be *quietly*
-- correct-looking but low.
--
-- A first fix released the band above 120% and left the middle one capped, so
-- the seller at 111% stayed wrong while the one at 141% was fixed. That is why
-- this test asserts the whole function, not one example: it checks the tier
-- input equals max(attainment, 100%) for every ramping seller, in every band.

select
    seller_email,
    display_name,
    attainment_applied,
    attainment_for_tier,
    greatest(coalesce(attainment_applied, 1.0000), 1.0000) as attainment_expected,
    tier_floor
from {{ ref('int_seller_attainment') }}
where rule_code = 'RAMP_UP'
  and attainment_for_tier
      is distinct from greatest(coalesce(attainment_applied, 1.0000), 1.0000)
