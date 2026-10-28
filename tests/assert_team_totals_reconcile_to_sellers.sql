-- The sum of the team totals must equal the sum of the sellers' revenue.
--
-- The two are computed along different paths: team totals come from
-- transaction-level attribution by sale date, seller totals from a
-- seller-level aggregate. They should agree to the cent, and the cases where
-- they would not -- a sale attributed to two teams, a seller dropped from one
-- side -- are precisely the ones worth catching.

with by_team as (
    select sum(gross_amount) as gross_amount
    from {{ ref('fct_team_month') }}
),

by_seller as (
    select sum(gross_amount) as gross_amount
    from {{ ref('int_seller_month') }}
    where rule_code != 'CS'
)

select
    by_team.gross_amount    as gross_by_team,
    by_seller.gross_amount  as gross_by_seller,
    cast(by_team.gross_amount - by_seller.gross_amount as decimal(14,2)) as difference
from by_team
cross join by_seller
where abs(by_team.gross_amount - by_seller.gross_amount) > 0.01
