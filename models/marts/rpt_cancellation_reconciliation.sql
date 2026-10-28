-- Two defensible readings of the same word, priced side by side.
--
-- The commission rule says payout is on revenue "net of churn". Upstream the
-- only flag available was `is_refunded`. Those are not the same event: a
-- contract can be cancelled without the money being returned, so every
-- cancelled-but-not-refunded sale is paid under one reading and not under the
-- other.
--
-- In production this surfaced as seven sellers whose gross matched a reference
-- dashboard to the cent while their net did not, each off by exactly one
-- transaction, always in the same direction. That shape -- gross agreeing, net
-- disagreeing, by whole transactions -- is the signature of a definition gap
-- rather than an arithmetic bug. No amount of re-running fixes it, because
-- nothing is broken.
--
-- This model does not pick a winner. It prices the disagreement, so the
-- decision can be made by the people who own the definition, with the cost in
-- front of them. Note which direction it runs: the refund reading pays MORE,
-- so if the dashboard's definition is the right one, the engine has been
-- overpaying -- and not only this month.
--
-- Tracked as an open question; see docs/02-churn-vs-refund.md.

with base as (

    select
        s.period_label,
        s.seller_email,
        s.display_name,
        s.team,
        s.rule_code,
        s.churned_not_refunded_count,
        s.net_amount_by_refund,
        s.net_amount_by_churn,
        s.net_full_by_refund,
        s.net_recurring_by_refund,
        s.net_full_by_churn,
        s.net_recurring_by_churn,
        -- the rate is driven by GROSS attainment, so it is identical under both
        -- readings; only the base moves
        a.pct_full,
        a.pct_recurring
    from {{ ref('int_seller_month') }} s
    join {{ ref('int_seller_attainment') }} a
        on a.seller_email = s.seller_email

),

priced as (

    select
        *,
        cast(net_full_by_refund * pct_full
             + net_recurring_by_refund * pct_recurring as decimal(12,2))
            as commission_if_refund,
        cast(net_full_by_churn * pct_full
             + net_recurring_by_churn * pct_recurring as decimal(12,2))
            as commission_if_churn
    from base

)

select
    period_label,
    seller_email,
    display_name,
    team,
    churned_not_refunded_count          as disputed_transactions,
    net_amount_by_refund,
    net_amount_by_churn,
    cast(net_amount_by_refund - net_amount_by_churn as decimal(12,2))
        as net_difference,
    commission_if_refund,
    commission_if_churn,
    cast(commission_if_refund - commission_if_churn as decimal(12,2))
        as commission_difference
from priced
where churned_not_refunded_count > 0
order by commission_difference desc
