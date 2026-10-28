-- The roster. Deliberately the system of record for target, team and rule,
-- even though a target also exists upstream.
--
-- Upstream is a photo of the present: when a seller leaves, their historical
-- rows can disappear retroactively. A target stored here is a target that does
-- not move after payroll has run.

with source as (

    select * from {{ ref('raw_seller_roster') }}

),

renamed as (

    select
        lower(trim(seller_email))                       as seller_email,
        display_name,
        team,
        leader_name,
        cast(monthly_target as decimal(12,2))           as monthly_target,
        nullif(upper(trim(coalesce(commission_rule, ''))), '') as commission_rule,
        cast(fixed_pct as decimal(6,4))                 as fixed_pct,
        lower(trim(is_active)) in ('yes', 'sim', 'true', 'y') as is_active,

        {% if var('inject_defect') == 'override_without_reason' %}
        -- defect: strip the justification but keep the override
        cast(manual_attainment_pct as decimal(8,4))     as manual_attainment_pct,
        cast(null as varchar)                           as manual_attainment_reason,
        {% else %}
        cast(manual_attainment_pct as decimal(8,4))     as manual_attainment_pct,
        nullif(trim(coalesce(manual_attainment_reason, '')), '') as manual_attainment_reason,
        {% endif %}

        coalesce(nullif(upper(trim(coalesce(commission_rule, ''))), ''), 'STANDARD') as rule_code

    from source

)

select * from renamed
