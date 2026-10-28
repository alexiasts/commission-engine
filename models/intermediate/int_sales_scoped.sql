-- Every sale inside the accounting period, with two things resolved:
--
--   1. which team owns the revenue, as of the DAY OF THE SALE
--   2. whether the sale counts as cancelled, under the configured definition
--
-- (1) exists because teams change mid-month. A team was dissolved on the 16th
-- and its sellers moved. Rolling a seller up by their *current* team would hand
-- a full month of revenue to whichever team they landed in. Attribution has to
-- happen per transaction, by date, or the leadership payout is wrong by however
-- much was sold in the first half of the month.
--
-- (2) is the open question documented in docs/02-churn-vs-refund.md. `refund`
-- and `churn` are different events: a contract can be cancelled without the
-- money being returned. Both are computed; the var picks which one pays.

with sales as (

    select * from {{ ref('stg_sales') }}
    where sale_date between date '{{ var("period_start") }}'
                        and date '{{ var("period_end") }}'

),

sellers as (

    select * from {{ ref('stg_sellers') }}

),

periods as (

    select * from {{ ref('stg_team_periods') }}

),

attributed as (

    select
        s.transaction_id,
        s.sale_date,
        s.seller_email,
        s.product_name,
        s.sale_type,
        s.gross_amount,
        s.is_refunded,
        s.is_churned,
        s.team_visible,

        sl.display_name,
        sl.rule_code,
        sl.is_active,

        -- the override wins for the stretch it covers; the roster covers the rest
        coalesce(p.team, sl.team)                   as team_at_sale,
        sl.team                                     as team_current,
        p.team is not null                          as team_from_override,

        sl.rule_code = 'CS'                         as is_cs

    from sales s
    left join sellers sl
        on sl.seller_email = s.seller_email
    left join periods p
        on p.seller_email = s.seller_email
       and s.sale_date between p.valid_from and p.valid_to

),

classified as (

    select
        *,

        -- the configured definition, used for payout
        {% if var('commission_base') == 'churn' %}
        is_churned                                  as is_cancelled,
        {% else %}
        is_refunded                                 as is_cancelled,
        {% endif %}

        -- both definitions kept side by side so the gap is measurable
        is_refunded                                 as is_cancelled_by_refund,
        is_churned                                  as is_cancelled_by_churn

    from attributed

)

select
    *,
    case when is_cancelled then cast(0 as decimal(12,2)) else gross_amount end
        as net_amount,
    case when is_cancelled_by_refund then cast(0 as decimal(12,2)) else gross_amount end
        as net_amount_by_refund,
    case when is_cancelled_by_churn then cast(0 as decimal(12,2)) else gross_amount end
        as net_amount_by_churn
from classified
