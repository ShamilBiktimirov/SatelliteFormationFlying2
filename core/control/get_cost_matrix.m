function cost_matrix = get_cost_matrix(demonstration_old, demonstration_new, formation, spacecraft, consts)

    options_precision = odeset('RelTol',1e-12,'AbsTol',1e-12);
    global T;

    rv_init = formation.rv;
    dt = [0 seconds(demonstration_new.deployment_time - formation.orbit_epoch)];
    options_precision = odeset('RelTol',1e-12,'AbsTol',1e-12);
    [t_vec_local, rv_ECI_local] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), dt, rv_init, options_precision);
    rv_ECI_local = rv_ECI_local';
    rv_ECI_target = rv_ECI_local(:,end);
    
    rv_orb_at_reconf = get_rv_from_analytic_HCW_solution(rv_ECI_target, demonstration_old.HCW_constants, consts);
    for i = 1:formation.N_sats
        rv_ECI_initial(i*6-5:i*6,1) = orb2ECI(rv_ECI_target, rv_orb_at_reconf(:,i), consts);
    end

    formation.geometry = [];
    demonstration = demonstration_new;
    f = waitbar(0,'Calculating reconf cost matrix & reconf parameters');    
    state_after_correction = zeros(formation.N_active_sats,formation.N_active_sats,6);
    dt_impulsive_correction = zeros(formation.N_active_sats,formation.N_active_sats);
%     tic;
    for i = 1:(size(demonstration.HCW_constants,2)-1)
        f = waitbar(i/(size(demonstration.HCW_constants,2)-1));        
        for j = 1:(size(demonstration.HCW_constants,2)-1)
            rv_ECI = [];
            t_vec = [];
            formation.geometry = [];

            formation.geometry(:,1) = [0; 0; 0; 0];
            formation.geometry(:,2) = demonstration.HCW_constants(:,1+j);
            formation.N_sats = size(formation.geometry,2);
            formation.N_active_sats = size(formation.geometry,2) - 1;
            rv_ECI(1:6,1) = rv_ECI_initial(1:6,1);            
            rv_ECI(7:12,1) = rv_ECI_initial(6*(i+1)-5:6*(i+1),1);

            mode = 3;
            [t_vec, rv_ECI, impulsive_maneuvers_dV(i,j), ~] = multisatellite_orbit_correction_3_impulse(rv_ECI(:,end), consts, spacecraft, formation, mode);
            state_after_correction(i,j,:) = rv_ECI(7:12, end);
            dt_impulsive_correction(i,j) = t_vec(end);            
        end
    end
%     toc;
    close(f);

    formation.N_sats = size(demonstration.HCW_constants,2);
    formation.N_active_sats = formation.N_sats - 1;
    dt_reconfiguration = max(dt_impulsive_correction,[], 'all');

    % Finding target orbit position after impulsive reconf
    rv_init = rv_ECI_initial(1:6);
    [t_vec_local, rv_ECI_local] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft),[0 dt_reconfiguration], rv_init, options_precision);
    rv_ECI_local = rv_ECI_local';
    target_orbit_rv_ECI_post_impulsive = rv_ECI_local(:,end);
    
    rv_ECI_post_impulsive = zeros(formation.N_sats*6, formation.N_active_sats);
    for i = 1:formation.N_active_sats
        rv_ECI_post_impulsive(1:6,i) = target_orbit_rv_ECI_post_impulsive;
    end
    for i = 1:size(demonstration.HCW_constants,2)-1
        for j = 1:size(demonstration.HCW_constants,2)-1
            if dt_impulsive_correction(i,j) ~= dt_reconfiguration
                rv_init = squeeze(state_after_correction(i,j,:));
                [t_vec_local, rv_ECI_local] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft),[dt_impulsive_correction(i,j) dt_reconfiguration], rv_init, options_precision);
                rv_ECI_local = rv_ECI_local';
                rv_ECI_post_impulsive(6*(i+1)-5:6*(i+1),j) = rv_ECI_local(:,end);
            else
                rv_ECI_post_impulsive(6*(i+1)-5:6*(i+1),j) = squeeze(state_after_correction(i,j,:));
            end
        end
    end
        
    f = waitbar(0,'Calculating post-impulsive continuous control matrix');
%     tic;
    for i = 1:formation.N_active_sats
        f = waitbar(i/(size(demonstration.HCW_constants,2)-1));        
        T = seconds(demonstration.deployment_time - formation.orbit_epoch) + dt_reconfiguration;
        mode = 1;
        formation.geometry(:,1) = [0;0;0;0];
        for j = 2:formation.N_sats
        formation.geometry(:,j) = demonstration.HCW_constants(:,i+1);
        end
        [t_vec_out, rv_ECI_out, continuous_post_correction_maneuvers_dV(:,i), ~] = continuous_post_correction(rv_ECI_post_impulsive(:,i), consts, spacecraft, formation, mode);        
        t_continuous_post_correction(i,1) = t_vec_out(end) - t_vec_out(2);
    end
%     toc;
    close(f);
    mean_dt_continuous_post_correction = mean(t_continuous_post_correction);
    reconfiguration_cost = impulsive_maneuvers_dV + continuous_post_correction_maneuvers_dV;
    rv_ECI = [];
    t_vec = [];
    rv_init = target_orbit_rv_ECI_post_impulsive;
    [t_vec_local, rv_ECI_local] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft),[0 mean_dt_continuous_post_correction], rv_init, options_precision);
    rv_ECI_local = rv_ECI_local';
    target_orbit_rv_ECI_post_continuous = rv_ECI_local(:,end);
    rv_orb_pre_maintenance = get_rv_from_analytic_HCW_solution(target_orbit_rv_ECI_post_continuous, demonstration.HCW_constants, consts);
    for i = 1:formation.N_sats
        rv_ECI(6*i-5:6*i,1) = orb2ECI(target_orbit_rv_ECI_post_continuous, rv_orb_pre_maintenance(:,i), consts);
    end
    
    formation.geometry = demonstration.HCW_constants;    
    T = seconds(demonstration.deployment_time - formation.orbit_epoch) + dt_reconfiguration + mean_dt_continuous_post_correction;
    t_vec = T;

    % Maintenance up to an image demonstration

    T_maintenance = demonstration.demo_time(1);
    dt_rude_control = seconds(minutes(10)); 
    
    [t_vec_maintenance, rv_ECI_maintenance, maneuvers_maintenance1] = maintenance(rv_ECI, T_maintenance, dt_rude_control, formation, spacecraft, consts);
    t_vec = [t_vec; t_vec_maintenance(2:end)];
    rv_ECI = [rv_ECI, rv_ECI_maintenance(:,2:end)];
    T = t_vec(end);

    % Stage 3. Image demonstration

    options_precision = odeset('RelTol',1e-12,'AbsTol',1e-12);
    [t_out, rv_ECI_out] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), [T:demonstration.demo_time(2)], rv_ECI(:,end), options_precision);
    rv_ECI_out = rv_ECI_out'; 
    rv_ECI = [rv_ECI, rv_ECI_out(:,2:end)];
    t_vec = [t_vec; t_out(2:end)];    
    T = t_vec(end);

    % 4. Maintenance up to the next reconfiguration
 
    T_maintenance = seconds(demonstration.reconfiguration_time - formation.orbit_epoch);
    dt_rude_control = seconds(minutes(5));
    [t_vec_maintenance, rv_ECI_maintenance, maneuvers_maintenance2] = maintenance(rv_ECI(:,end),T_maintenance, dt_rude_control, formation, spacecraft, consts);
    t_vec = [t_vec; t_vec_maintenance(2:end)];
    rv_ECI = [rv_ECI, rv_ECI_maintenance(:,2:end)];
    T = t_vec(end);

    maintenance_cost = maneuvers_maintenance1 + maneuvers_maintenance2;

    cost_matrix.reconfiguration_cost = reconfiguration_cost;
    cost_matrix.maintenance_cost = maintenance_cost;
    cost_matrix.maneuvers_maintenance1 = maneuvers_maintenance1;    
    cost_matrix.maneuvers_maintenance2 = maneuvers_maintenance2;
    cost_matrix.state_after_correction = state_after_correction;
    cost_matrix.impulsive_maneuvers_dV = impulsive_maneuvers_dV;
    cost_matrix.continuous_post_correction_maneuvers_dV = continuous_post_correction_maneuvers_dV;
    
end
