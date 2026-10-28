-- One row per transaction, typed and normalised.
--
-- `gross_amount` is cast to DECIMAL on the way in, never FLOAT and never
-- inferred. The production incident this project is modelled on came from an
-- amount arriving as the string "1558.8" and being read as a date by a
-- pt-BR locale, then back out as epoch milliseconds. An explicit decimal cast
-- at the boundary is the cheapest insurance there is.

with source as (

    select * from {{ ref('raw_sales_transactions') }}

),

renamed as (

    select
        transaction_id,
        sale_date,
        lower(trim(seller_email))              as seller_email,
        product_name,
        upper(trim(sale_type))                 as sale_type,
        cast(gross_amount as decimal(12,2))    as gross_amount,
        is_refunded,
        is_churned,
        team_visible,
        strftime(sale_date, '%Y-%m')           as period_label

    from source

)

select * from renamed
