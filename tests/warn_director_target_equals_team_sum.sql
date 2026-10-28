{{ config(severity = 'warn') }}

-- The director is measured against the COMPANY target, which is a different
-- number from the sum of the team targets.
--
-- Team quotas are set individually and do not add up to the company
-- commitment. Substituting the sum changes the denominator, which changes the
-- attainment, which can change the band -- in the data here, R$ 9.902,74 under
-- the company target against R$ 12.732,09 under the sum, for the same month,
-- with nothing on the report to indicate which one was used.
--
-- This warns if the two ever coincide, because at that point the model stops
-- being able to tell a deliberate company target from a sum someone pasted in.

with director as (
    select team_target from {{ ref('stg_leadership') }} where role = 'DIRECTOR'
),

team_sum as (
    select sum(team_target) as team_target from {{ ref('stg_leadership') }} where role = 'TL'
)

select
    director.team_target as company_target,
    team_sum.team_target as sum_of_team_targets
from director
cross join team_sum
where director.team_target = team_sum.team_target
