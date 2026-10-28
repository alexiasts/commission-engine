{{ config(severity = 'warn') }}

-- A registered seller with nothing at all in the period.
--
-- Sometimes true (leave, a late start) and sometimes the symptom of an address
-- that does not match upstream. The two are indistinguishable from the data, so
-- this cannot be an error -- but it must never pass unseen, because the silent
-- version of this is a real person paid nothing.

select
    seller_email,
    display_name,
    team,
    monthly_target
from {{ ref('int_seller_month') }}
where had_no_sales
