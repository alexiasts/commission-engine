-- Slowly-changing team membership, kept as closed intervals [valid_from, valid_to].
--
-- Normally empty: when nobody moved, the roster team covers the whole month and
-- the result is identical. Rows are added only for the stretch BEFORE a move.

with source as (

    select * from {{ ref('raw_team_periods') }}

    {% if var('inject_defect') == 'overlapping_periods' %}
    -- defect: a second interval covering days the first one already claims,
    -- which would make the same sale count for two teams
    union all
    select
        seller_email,
        'Megalodon' as team,
        date '2026-09-10' as valid_from,
        date '2026-09-20' as valid_to,
        'defeito injetado' as note
    from {{ ref('raw_team_periods') }}
    where valid_from = date '2026-09-01'
    {% endif %}

)

select
    lower(trim(seller_email)) as seller_email,
    nullif(trim(team), '')    as team,
    valid_from,
    valid_to,
    note
from source
