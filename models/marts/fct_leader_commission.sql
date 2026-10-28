-- Leadership payout. Three roles, three bases.
--
--   TL        the team they lead, attained against the TEAM target
--   DIRECTOR  the whole operation -- every team plus CS -- attained against the
--             COMPANY target
--   TL_CS     a flat rate on CS net, no team and no target
--
-- The director's denominator is the one worth flagging. The company target and
-- the sum of the team targets are two different numbers -- team quotas are set
-- one at a time and do not add up to the company commitment, in either
-- direction -- and substituting one for the other changes the attainment,
-- which changes the band, with nothing on the report to say which was used.
-- In the figures here the two readings are R$ 9.902,74 against the company
-- target and R$ 12.732,09 against the sum, for the same month.
--
-- Note that revenue from a team with no current leader -- a team dissolved
-- mid-period, say -- reaches no TL, but still counts for the director. The
-- company billed it either way.

with leaders as (

    select * from {{ ref('stg_leadership') }}

),

teams as (

    select * from {{ ref('fct_team_month') }}

),

cs_total as (

    select
        sum(net_amount)  as net_amount,
        sum(gross_amount) as gross_amount
    from {{ ref('int_sales_scoped') }}
    where is_cs

),

company_total as (

    select
        sum(gross_amount) as gross_amount,
        sum(net_amount)   as net_amount
    from {{ ref('int_sales_scoped') }}

),

scoped as (

    -- team leaders
    select
        l.leader_email,
        l.leader_name,
        l.role,
        l.scope,
        l.team_target                       as target_amount,
        t.gross_amount,
        t.net_amount
    from leaders l
    left join teams t
        on t.team = l.scope
    where l.role = 'TL'

    union all

    -- director: the whole operation, against the company target
    select
        l.leader_email,
        l.leader_name,
        l.role,
        l.scope,
        l.team_target                       as target_amount,
        c.gross_amount,
        c.net_amount
    from leaders l
    cross join company_total c
    where l.role = 'DIRECTOR'

    union all

    -- CS leader: flat rate, no attainment
    select
        l.leader_email,
        l.leader_name,
        l.role,
        l.scope,
        cast(null as decimal(14,2))         as target_amount,
        cs.gross_amount,
        cs.net_amount
    from leaders l
    cross join cs_total cs
    where l.role = 'TL_CS'

),

attained as (

    select
        *,
        case
            when target_amount is null or target_amount = 0 then null
            else cast(gross_amount / target_amount as decimal(10,4))
        end as attainment
    from scoped

),

priced as (

    select
        a.*,
        lt.min_attainment as tier_floor,
        lt.pct
    from attained a
    left join {{ ref('stg_leader_tiers') }} lt
        on lt.role = a.role
       and lt.min_attainment = (
            select max(lt2.min_attainment)
            from {{ ref('stg_leader_tiers') }} lt2
            where lt2.role = a.role
              and lt2.min_attainment <= coalesce(a.attainment, 0)
        )

)

select
    '{{ var("period_label") }}' as period_label,
    leader_email,
    leader_name,
    role,
    scope,
    target_amount,
    gross_amount,
    net_amount,
    attainment,
    tier_floor,
    pct,
    cast(net_amount * pct as decimal(12,2)) as commission_total
from priced
