clear all;

%% Simulation parameters and initial conditions
global environment
environment = 'J2';
syms t;

consts = startup_formation_control();
spacecraft.dr_observation = 300e3;

initial_epoch = datetime(2023, 1, 1, 0, 0, 0); 

oe_cluster1(1) = consts.rEarth + 670e3; 
oe_cluster1(2) = 0;
oe_cluster1(3) = get_SSO_inclination(oe_cluster1(1), oe_cluster1(2), consts);
oe_cluster1(4) = get_RAAN_for_terminator_orbit(initial_epoch);
oe_cluster1(5:6) = 0;

oe_cluster2(1) = consts.rEarth + 730e3; 
oe_cluster2(2) = 0;
oe_cluster2(3) = get_SSO_inclination(oe_cluster2(1), oe_cluster2(2), consts);
oe_cluster2(4) = get_RAAN_for_terminator_orbit(initial_epoch);
oe_cluster2(5) = 0;
oe_cluster2(6) = 0;

rv_cluster1_fun = analytical_rv_function(oe_cluster1, 'm, s', consts);
rv_cluster2_fun = analytical_rv_function(oe_cluster2, 'm, s', consts);
rv_cluster1 = oe2rv(oe_cluster1, consts);
rv_cluster2 = oe2rv(oe_cluster2, consts);

a_range = [(consts.rEarth + 600e3) : 2000 : (consts.rEarth + 800e3)];
step = length(a_range);
i_range = [0 : pi/step : (pi-pi/step)];
RAAN_range = [0 : 2*pi/step : (2*pi-2*pi/step)];
MA_range = [0 : 2*pi/step : (2*pi-2*pi/step)];
oe_range = [a_range; i_range; RAAN_range; MA_range];

oe_d(1) = oe_range(1, 1);
oe_d(3) = oe_range(2, 1);
oe_d(3) = 1.71139023772152;
oe_d(4) = oe_range(3, 1);
oe_d(4) = 0.1954;
oe_d(6) = oe_range(4, 1);
oe_d(2) = 0;
oe_d(5) = 0;

rv_d_fun = analytical_rv_function(oe_d, 'm, s', consts);
dr = norm(rv_cluster1_fun(1:3) - rv_d_fun(1:3));
hold on;
fplot(dr, [1 consts.day2sec*10]);
hold on;
xlabel('t, s');
ylabel('dr, m');
% eq1 = dr1 == sym(spacecraft.dr_observation);
% dr2 = norm(rv_cluster2_fun(1:3) - rv_d_fun(1:3));
oe_d1 = oe_d;
oe_d2 = oe_d;
oe_d2(3) = oe_cluster1(3);
oe_d2(4) = oe_cluster1(4);

rv_d1 = oe2rv(oe_d1, consts);
rv_d2 = oe2rv(oe_d2, consts);
plot_orbits(rv_d2, consts);
rv_d1_fun = analytical_rv_function(rv_d1, 'm, s', consts);
rv_d2_fun = analytical_rv_function(rv_d2, 'm, s', consts);
dr1 = norm(rv_cluster1_fun(1:3) - rv_d1_fun(1:3));
dr2 = norm(rv_cluster1_fun(1:3) - rv_d2_fun(1:3));

figure;
% % subplot(1,2,1);
fplot(dr1, [1, consts.day2sec*10]);
hold on;
fplot(dr2, [1, consts.day2sec*10]);
yline(spacecraft.dr_observation);
% hold on;
% subplot(1,2,2);
% fplot(dr2, [1, consts.day2sec*10]);
% hold on;
% yline(spacecraft.dr_observation);

tic;
for i = 1:size(oe_range,2)
   oe_d(1) = oe_range(1, i);
   rv_d_fun = analytical_rv_function(oe_d, 'm, s', consts);
   dr1 = norm(rv_cluster1_fun(1:3) - rv_d_fun(1:3));
   dr2 = norm(rv_cluster2_fun(1:3) - rv_d_fun(1:3));
   eq1 = dr1 == sym(spacecraft.dr_observation);
   eq2 = dr2 == sym(spacecraft.dr_observation);
    tic;
    tau_max(i,1) = dr_oscillations_period(eq1, t);
    tau_max(i,2) = dr_oscillations_period(eq2, t);
    toc;
    disp(['iteration',i]);
    disp(['Coverage time, days', tau_max(i,:)/consts.day2sec]);
    
end
toc;

% 1. the first experiment is with equatorial target orbit
% 2. Coplanar orbit
% 3. SSO, perpendicular to terminator
% I predict that maximum observation time should be moreless the same for
% three test cases

figure;
plot(oe_range(1,:) - consts.rEarth, tau_max(:,1));
hold on;
plot(oe_range(1,:) - consts.rEarth, tau_max(:,2));
xlabel('debris orbit sma, m');
ylabel('\tau_{max}');
legend('Cluster_1 (h = 670 km)', 'Cluster_2 (h = 730 km)');



function tau_max = dr_oscillations_period(fun, var)

    step = 2e5;
    max_time = consts.day2sec * 10;
    [tau1, root1_step] =  custom_solver(fun, var, 0, step, max_time);
    [tau2, root2_step] =  custom_solver(fun, var, root1_step, step,max_time);
    tau_max = tau2 - tau1;

end

% tic;
% tau_observation = numerical_tau_max(oe_range, rv_cluster1_fun, rv_cluster2_fun, oe_cluster1(1), oe_cluster2(1), spacecraft.dr_observation, consts);
% toc;

function [t_obs_max] = numerical_tau_max(variables, rv_obs1_fun, rv_obs2_fun, a1, a2, r_obs, consts)
    syms t
    oe_d = zeros(6,1);
    t_obs_max = 0;
    for i = 1:size(variables,2)
        for j = 1:size(variables,2)
            for k = 1:size(variables,2)
                for l = 1:size(variables,2)
                    
                    oe_d(1) = variables(1, i);
                    oe_d(3) = variables(2, j);
                    oe_d(4) = variables(3, k);
                    oe_d(6) = variables(4, l);
                    
                    rv_d_fun = analytical_rv_function(oe_d, 'm, s', consts);
                    dr1 = norm(rv_obs1_fun(1:3) - rv_d_fun(1:3));
                    dr2 = norm(rv_obs2_fun(1:3) - rv_d_fun(1:3));

                    if double(subs(dr1, t, 0)) < r_obs || double(subs(dr2, t, 0)) < r_obs
                        tau = 0;
                    else
                       if abs(variables(1,i) - a1) < 10e3
                           eq2 = dr2 - sym(r_obs) == sym(0);
                           tau = double(custom_solver(eq2, t, 1e4));
                       elseif abs(variables(1,i) - a2) < 10e3
                           eq1 = dr1 - sym(r_obs) == sym(0);
                           tau = double(custom_solver(eq1, t, 1e4));
                       else
                           eq1 = dr1 - sym(r_obs) == sym(0);
                           eq2 = dr2 - sym(r_obs) == sym(0);
                           tau1 = double(custom_solver(eq1, t, 1e5));
                           tau2 = double(custom_solver(eq2, t, 1e5));
                           disp([tau1, tau2]);
                           if tau1 < tau2
                               tau = tau1;
                           else
                               tau = tau2;
                           end
                       end
                    end
                    if tau > t_obs_max
                        t_obs_max = tau;
                    end
                    
                end
            end
        end
    end
end
