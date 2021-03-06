function tau = time_to_observation(variables, variables_range, rv_obs_fun, dr_observation_max, consts)

% The function searches for the time to observation for a given orbit of
% observer and an orbit of a space debris

% We assume that space debris orbits are circular
syms t positive

a_d = variables(1);
M_d = variables(2);
% i_d = variables(2);
% RAAN_d = variables(3);

NaN_condition(1,1) = variables_range(1,1) > a_d | a_d > variables_range(1,2);
NaN_condition(2,1) = variables_range(2,1) > M_d | M_d > variables_range(2,2);
% NaN_condition(2,1) = variables_range(2,1) > i_d | i_d > variables_range(2,2);
% NaN_condition(3,1) = variables_range(3,1) > RAAN_d | RAAN_d > variables_range(3,2);

if sum(NaN_condition) == 0   
    oe_d(1,1) = a_d;
    oe_d(2,1) = 0;
    oe_d(3,1) = 0;
    oe_d(4,1) = 0;
    oe_d(5,1) = 0;
    oe_d(6,1) = M_d;

    rv_d_fun = analytical_rv_function(oe_d, 'm, s', consts);

    dr = rv_obs_fun(1:3) - rv_d_fun(1:3);
    distance = norm(dr);

    if double(subs(distance, t, 0)) < dr_observation_max
        tau_analytical = 0;
    else
        eq = distance - sym(dr_observation_max) == sym(0);
        tau_analytical = custom_solver(eq, t, 3e4);
    end
        tau = double(-tau_analytical);
else
    tau = inf;
end
    disp(tau);

