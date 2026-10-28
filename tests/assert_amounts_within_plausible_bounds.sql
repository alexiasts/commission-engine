-- A data contract on the amount column, and a scar from a real incident.
--
-- Amounts once arrived as strings. A pt-BR locale read "1558.8" as a date in
-- the year 1558, stored it as a date serial, and the script read it back as
-- epoch milliseconds: a single sale became roughly -1.3e13, and a month of them
-- summed to R$ 303.492.614.788.000,00. It was caught because the number was
-- absurd. A date in 1970 instead of 1558 would have produced a figure merely
-- wrong, and it would have been paid.
--
-- The structural fix is the explicit decimal cast in stg_sales. This is the
-- belt to that pair of braces: no commission line may fall outside the range a
-- human would recognise as money.

select
    transaction_id,
    sale_date,
    seller_email,
    gross_amount
from {{ ref('stg_sales') }}
where gross_amount is null
   or gross_amount <= 0
   or gross_amount > 100000
