select
    lower(trim(leader_email))          as leader_email,
    leader_name,
    upper(trim(role))                  as role,
    scope,
    cast(team_target as decimal(14,2)) as team_target
from {{ ref('raw_leadership') }}
