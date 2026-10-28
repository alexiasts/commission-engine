-- FULL + RECURRING must account for the whole net figure.
--
-- If a transaction arrives with a sale type outside the two known values, it
-- silently drops out of both commission legs: the seller is paid nothing for a
-- real sale, and the totals still look internally consistent. This is the test
-- that catches a new product category nobody mentioned.

select
    seller_email,
    display_name,
    net_amount,
    net_full,
    net_recurring,
    cast(net_amount - (net_full + net_recurring) as decimal(12,2)) as unaccounted
from {{ ref('int_seller_month') }}
where abs(net_amount - (net_full + net_recurring)) > 0.01
