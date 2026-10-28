-- One row per seller per period: the raw material of the payout.
--
-- Driven by the ROSTER, not by the sales: a seller who sold nothing still gets
-- a row, with zeros. If they disappeared instead, "nobody noticed X was missing"
-- becomes a possible failure mode, and silence is the worst thing a payroll
-- pipeline can produce.
--
-- The two bases are deliberately separate columns, because the business rule
-- uses BOTH and mixing them up is the single most expensive mistake available
-- here:
--
--   attainment  is measured on GROSS   (a cancellation does not demote you)
--   commission  is paid    on NET      (you are not paid for a cancelled sale)
--
-- Stated out loud it sounds arbitrary; it is not. The seller controls the sale,
-- not the customer's later change of mind, so the tier they earned stands. But
-- the company never collected the money, so it is not commissionable.

with sellers as (

    select * from {{ ref('stg_sellers') }}

),

aggregated as (

    select
        seller_email,

        count(*)                                    as sale_count,
        count(*) filter (where is_cancelled)        as cancelled_count,

        -- attainment base
        sum(gross_amount)                           as gross_amount,
        sum(gross_amount) filter (where sale_type = 'FULL')      as gross_full,
        sum(gross_amount) filter (where sale_type = 'RECURRING') as gross_recurring,

        -- payout base, split by sale type because the two pay different rates
        sum(net_amount)                             as net_amount,
        sum(net_amount) filter (where sale_type = 'FULL')      as net_full,
        sum(net_amount) filter (where sale_type = 'RECURRING') as net_recurring,

        -- the same net under both definitions, for reconciliation
        sum(net_amount_by_refund)                   as net_amount_by_refund,
        sum(net_amount_by_churn)                    as net_amount_by_churn,
        sum(net_amount_by_refund) filter (where sale_type = 'FULL')      as net_full_by_refund,
        sum(net_amount_by_refund) filter (where sale_type = 'RECURRING') as net_recurring_by_refund,
        sum(net_amount_by_churn)  filter (where sale_type = 'FULL')      as net_full_by_churn,
        sum(net_amount_by_churn)  filter (where sale_type = 'RECURRING') as net_recurring_by_churn,
        count(*) filter (where is_churned and not is_refunded)           as churned_not_refunded_count

    from {{ ref('int_sales_scoped') }}
    group by all

)

select
    '{{ var("period_label") }}'                     as period_label,
    s.seller_email,
    s.display_name,
    s.team,
    s.leader_name,
    s.rule_code,
    s.is_active,
    s.monthly_target,
    s.fixed_pct,
    s.manual_attainment_pct,
    s.manual_attainment_reason,

    coalesce(a.sale_count, 0)                                   as sale_count,
    coalesce(a.cancelled_count, 0)                              as cancelled_count,
    coalesce(a.gross_amount, cast(0 as decimal(12,2)))          as gross_amount,
    coalesce(a.gross_full, cast(0 as decimal(12,2)))            as gross_full,
    coalesce(a.gross_recurring, cast(0 as decimal(12,2)))       as gross_recurring,
    coalesce(a.net_amount, cast(0 as decimal(12,2)))            as net_amount,
    coalesce(a.net_full, cast(0 as decimal(12,2)))              as net_full,
    coalesce(a.net_recurring, cast(0 as decimal(12,2)))         as net_recurring,
    coalesce(a.net_amount_by_refund, cast(0 as decimal(12,2)))      as net_amount_by_refund,
    coalesce(a.net_amount_by_churn, cast(0 as decimal(12,2)))       as net_amount_by_churn,
    coalesce(a.net_full_by_refund, cast(0 as decimal(12,2)))        as net_full_by_refund,
    coalesce(a.net_recurring_by_refund, cast(0 as decimal(12,2)))   as net_recurring_by_refund,
    coalesce(a.net_full_by_churn, cast(0 as decimal(12,2)))         as net_full_by_churn,
    coalesce(a.net_recurring_by_churn, cast(0 as decimal(12,2)))    as net_recurring_by_churn,
    coalesce(a.churned_not_refunded_count, 0)                       as churned_not_refunded_count,

    a.seller_email is null                                      as had_no_sales

from sellers s
left join aggregated a
    on a.seller_email = s.seller_email
