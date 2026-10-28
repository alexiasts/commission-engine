-- An overridden attainment without a written justification is an error, and it
-- blocks the whole run.
--
-- Exceptions are legitimate -- a departure paid at 100% by agreement, an
-- attainment the business validated differently. What is not legitimate is an
-- exception nobody can explain six months later. Making the reason mandatory
-- costs the person one sentence at the moment they already know the answer,
-- and it puts that sentence in the same row as the number forever.

select
    seller_email,
    display_name,
    manual_attainment_pct,
    manual_attainment_reason
from {{ ref('stg_sellers') }}
where manual_attainment_pct is not null
  and manual_attainment_reason is null
