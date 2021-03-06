clear all;

%% Simulation parameters and initial conditions
global environment
environment = 'point mass';
syms t;

consts = startup_formation_control();
simulation_start_GD = datetime(2050,1,1,0,0,0);
simulation_start_JD = juliandate(simulation_start_GD);

% Asteroid database
MBA_table = readtable('MBA.csv');

% Define unknown asteroids and study it

obs_ast = table2array(MBA_table(MBA_table.spkid == 3529604,:));
unknown_asteroids = table2array(MBA_table(isnan(MBA_table.diameter),:));

oe_obs = obs_ast(1, 3:8);
oe_obs(6) = mod(oe_obs(6) + (simulation_start_JD - obs_ast(2))*obs_ast(10), 360);
oe_obs(3:6) = deg2rad(oe_obs(3:6));

% analytical position function
rv_obs_fun = analytical_rv_function(oe_obs, 'AU, d', consts);

[asteroid, obs_time] = find_observation_candidates(rv_obs_fun, simulation_start_JD, unknown_asteroids, consts);

function [asteroid_candidate, tau_obs] = find_observation_candidates(rv_obs, simulation_start_JD, asteroids_list, consts)
    syms t
    i = 0;
    n = 0;
    asteroid_candidate = [];
    tau_obs = [];
    
    while n <= 100
        i = i + 1;
        targ_ast = asteroids_list(i,:);
        oe_targ = targ_ast(1, 3:8);
        oe_targ(6) = mod(oe_targ(6) + (simulation_start_JD - targ_ast(2))*targ_ast(10), 360);
        oe_targ(3:6) = deg2rad(oe_targ(3:6));
        rv_targ = analytical_rv_function(oe_targ, 'AU, d', consts);
        dr = norm(rv_obs(1:3) - rv_targ(1:3));
        % visualization
%         figure('Name', 'Distance between asteroids');
%         fplot(dr, [1 10*365]);
%         xlabel('time, day');
%         ylabel('distance, AU');
%         grid on;
        
        equation = dr == 1;
        [tau,~] = custom_solver(equation, t, 0, 1*365, 10*365);

        if tau ~= inf && ~isempy(tau)
            n = n + 1;
            asteroid_canditate(n,:) = asteroids_list(i,:);
            tau_obs(n) = tau;
        end
    end
end
