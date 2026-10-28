select
    upper(trim(role))                    as role,
    cast(min_attainment as decimal(8,4)) as min_attainment,
    cast(pct            as decimal(6,4)) as pct
from {{ ref('raw_leader_tiers') }}
