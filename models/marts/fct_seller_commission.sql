-- The payout, one row per seller per period. This is the number a person is
-- paid, so every input that produced it travels alongside it:
--
--   attainment_computed   what the arithmetic said
--   attainment_applied    what was actually used
--   manual_override_reason  why, if those two differ
--   tier_floor            which band that bought
--   net_* / pct_*         the base and the rate, so the arithmetic is reproducible
--                         by hand from this row alone
--
-- `is_payable` is not the same as "has revenue". Someone who left mid-period
-- still sold while they were here: their revenue counts for the team, their
-- commission is settled in the termination agreement, and they show up here
-- with a payout of zero and a reason. Dropping their row instead would silently
-- shrink the team total their leader is measured on.

with base as (

    select * from {{ ref('int_seller_attainment') }}

),

priced as (

    select
        period_label,
        seller_email,
        display_name,
        team,
        leader_name,
        rule_code,
        is_active,
        had_no_sales,

        monthly_target,
        sale_count,
        cancelled_count,

        gross_amount,
        net_amount,
        net_full,
        net_recurring,

        attainment_computed,
        attainment_applied,
        attainment_for_tier,
        has_manual_override,
        manual_attainment_reason      as manual_override_reason,
        tier_floor,
        pct_full,
        pct_recurring,

        {% if var('inject_defect') == 'commission_on_gross' %}
        -- defect: pays on gross instead of net, i.e. pays for sales that were
        -- refunded. Inflates every payout touched by a cancellation.
        cast(gross_full      * pct_full      as decimal(12,2)) as commission_full,
        cast(gross_recurring * pct_recurring as decimal(12,2)) as commission_recurring
        {% else %}
        cast(net_full        * pct_full      as decimal(12,2)) as commission_full,
        cast(net_recurring   * pct_recurring as decimal(12,2)) as commission_recurring
        {% endif %}

    from base

)

select
    *,
    cast(commission_full + commission_recurring as decimal(12,2))
        as commission_total,

    is_active as is_payable,

    cast(case when is_active
              then commission_full + commission_recurring
              else 0 end as decimal(12,2))
        as amount_payable,

    case
        when not is_active
            then 'Fora da apuracao: saiu no periodo, acerto em rescisao'
        when had_no_sales
            then 'Sem vendas no periodo'
        when has_manual_override
            then 'Atingimento ajustado manualmente'
    end as payout_note

from priced
