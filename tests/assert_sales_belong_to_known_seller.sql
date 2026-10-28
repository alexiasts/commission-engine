-- Every transaction in the period must match a seller on the roster.
--
-- An unmatched sale is revenue that reaches no payout and no team total. The
-- usual cause is mundane -- someone has two addresses, or joined without being
-- registered -- and the usual symptom is a person quietly paid nothing.
--
-- Matching is on email, never on name. Names are not unique (two people share
-- a first name), not stable (upstream has the full name, the roster has the
-- short one), and the failure mode of a near-match is an empty row rather than
-- an error.

select
    s.transaction_id,
    s.sale_date,
    s.seller_email,
    s.gross_amount
from {{ ref('int_sales_scoped') }} s
where s.display_name is null
