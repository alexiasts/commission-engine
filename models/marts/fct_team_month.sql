-- Team revenue, summed TRANSACTION BY TRANSACTION using the team that owned
-- the seller on the date of each sale.
--
-- Not `group by seller.team`. That shortcut is wrong the moment anyone moves,
-- and it is wrong silently: the totals still look plausible, they just belong
-- to the wrong leader. Here, a seller who moved on the 16th contributes the
-- first half of the month to one team and the second half to another.
--
-- Customer Success is excluded from team totals on purpose. CS revenue is not
-- team-visible and is not part of what a sales team leader is measured on --
-- folding it in would inflate the leader's attainment with revenue they did not
-- lead. It reappears at director level, where the whole operation counts.

select
    '{{ var("period_label") }}'  as period_label,
    team_at_sale                 as team,

    count(*)                     as sale_count,
    count(distinct seller_email) as seller_count,

    sum(gross_amount)            as gross_amount,
    sum(net_amount)              as net_amount,
    sum(net_amount_by_refund)    as net_amount_by_refund,
    sum(net_amount_by_churn)     as net_amount_by_churn

from {{ ref('int_sales_scoped') }}
where not is_cs
group by all
