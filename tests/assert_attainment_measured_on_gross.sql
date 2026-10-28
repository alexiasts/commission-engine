-- Attainment is measured on GROSS revenue.
--
-- The mirror image of the test above, and the half people get wrong in the
-- other direction: a cancellation must not demote the seller to a lower band.
-- They made the sale; the customer's later change of mind is not theirs.
--
-- Rows with a manual override are excluded -- the override is a deliberate
-- substitution of this figure, and it is guarded by its own test.

select
    seller_email,
    display_name,
    gross_amount,
    monthly_target,
    attainment_computed,
    cast(gross_amount / monthly_target as decimal(10,4)) as attainment_expected
from {{ ref('fct_seller_commission') }}
where monthly_target is not null
  and monthly_target > 0
  and abs(attainment_computed - cast(gross_amount / monthly_target as decimal(10,4))) > 0.0001
