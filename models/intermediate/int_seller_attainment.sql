-- Attainment, and the tier it buys.
--
-- Three ways a seller can be measured:
--
--   STANDARD  gross / target, straight into the tier table. No target is an
--             error, not a zero — see tests/assert_standard_seller_has_target.sql
--
--   RAMP_UP   a new hire still inside their ramp window. 100% is a FLOOR, not a
--             ceiling: they cannot land below the 100% tier, and if they beat it
--             they keep what they beat it with. The upstream mart got this
--             backwards and pinned every ramping seller to the 100-109.99 band,
--             which quietly underpaid the ones doing best. That is the single
--             regression this model exists to prevent; see
--             tests/assert_ramp_up_floor_not_ceiling.sql
--
--   CS        customer success. A flat rate on net, no target, no tier.
--
-- On top of that, `manual_attainment_pct` overrides the computed figure for a
-- documented exception. It changes ONLY the tier, never the payout base, and it
-- is inert without a written reason: the guard is in
-- tests/assert_manual_override_has_reason.sql. The point is that in six months
-- the answer to "why was this person paid that?" sits in the same row as the
-- number.

with base as (

    select * from {{ ref('int_seller_month') }}

),

computed as (

    select
        *,

        case
            when monthly_target is null or monthly_target = 0 then null
            else cast(gross_amount / monthly_target as decimal(10,4))
        end as attainment_computed

    from base

),

applied as (

    select
        *,

        -- what the arithmetic produced vs. what was actually used
        coalesce(manual_attainment_pct, attainment_computed) as attainment_applied,
        manual_attainment_pct is not null                    as has_manual_override

    from computed

),

for_tier as (

    select
        *,

        case
            when rule_code = 'RAMP_UP' then
                {% if var('inject_defect') == 'ramp_ceiling' %}
                -- defect: reproduces the upstream bug. 100% becomes a ceiling
                -- as well as a floor, so a ramping seller at 140% is paid at the
                -- 100% band.
                least(greatest(coalesce(attainment_applied, 1.0000), 1.0000), 1.0999)
                {% else %}
                greatest(coalesce(attainment_applied, 1.0000), 1.0000)
                {% endif %}
            else attainment_applied
        end as attainment_for_tier

    from applied

),

tiered as (

    select
        f.*,
        t.min_attainment as tier_floor,
        t.pct_full,
        t.pct_recurring
    from for_tier f
    left join {{ ref('stg_commission_tiers') }} t
        -- the tier is the highest floor the seller clears
        on t.min_attainment = (
            select max(t2.min_attainment)
            from {{ ref('stg_commission_tiers') }} t2
            where t2.min_attainment <= f.attainment_for_tier
        )
    where f.rule_code != 'CS'

    union all

    -- CS bypasses the tier table entirely
    select
        f.*,
        cast(null as decimal(8,4)) as tier_floor,
        f.fixed_pct                as pct_full,
        f.fixed_pct                as pct_recurring
    from for_tier f
    where f.rule_code = 'CS'

)

select * from tiered
