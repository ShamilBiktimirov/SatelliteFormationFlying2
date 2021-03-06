function [t_vec,rv_ECI, maneuvers_out, formation_fuel_level_out, formation_geometry2, T_event, Formation_state] = formation_hybrid_control(rv_ECI, Cost_matrix_dV, consts, spacecraft, formation)
 
    global T;
    t_vec =[T];
    maneuvers = []; % dV magnitudes for corrections
    maneuvers_out = [];
    % Event functions
    tracking_formation_quality = @(t, rv) formation_quality(rv_ECI, consts, spacecraft, formation);
    options_quality = odeset('RelTol',1e-12,'AbsTol',1e-12, 'Events', tracking_formation_quality);

%% Stage 1. Deployment (starts immediately at orbit epoch)
    maneuvers_deployment = [];

    disp('Initial deployment');
    mode = 1;
    [t_vec_m, rv_ECI_m, maneuvers_dV, formation_fuel_level] = multisatellite_orbit_correction_3_impulse(rv_ECI(:,end), consts, spacecraft, formation, mode);

    maneuvers_deployment = [maneuvers_deployment, maneuvers_dV];
    formation.fuel_level = formation_fuel_level;
    t_vec = [t_vec; t_vec_m];
    rv_ECI = [rv_ECI, rv_ECI_m];
    T = t_vec(end);
                
    mode = 11;
    [t_vec_out, rv_ECI_out, maneuvers_dV, formation_fuel_level] = continuous_control(rv_ECI(:,end), consts, spacecraft, formation, mode);

    maneuvers_deployment = [maneuvers_deployment, maneuvers_dV];
    formation.fuel_level = formation_fuel_level;
    t_vec = [t_vec; t_vec_out];
    rv_ECI = [rv_ECI, rv_ECI_out];
    
    T = t_vec(end);
    quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);

    disp(['Deployment took ' num2str((t_vec(end) - t_vec(1))/60) ' minutes, impulsive corrections: ' num2str(t_vec_m(end)/60) ' min, continuous control: ' num2str((t_vec_out(end) - t_vec_out(1))/60) ' min']);
    
    maneuvers_out = sum(maneuvers_deployment,2);
    formation_fuel_level_out = formation_fuel_level(:,end);
    T_event = [t_vec(1); t_vec(end)]; 
    Formation_state = 1;
    
%% Stage 2. Formation flying with maintenance (maintenance upt to demonstration 1)

    T_event = [T_event; T];                
    while T < formation.demo_time(1,1)

        quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);
        maneuvers_maintenance1 = [];

        disp('Formation Flying');
        while quality == 1
        [t_vec_FF, rv_ECI_FF, te, ye, ie] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), [T T+100], rv_ECI(:,end), options_quality);
        rv_ECI_FF = rv_ECI_FF';
        rv_ECI = [rv_ECI, rv_ECI_FF];
        t_vec = [t_vec; t_vec_FF ];
        T = t_vec(end);
        quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);
        
        end
        if T < formation.demo_time(1,1) && quality == 0                   
            disp('Orbit Maintenance');
            mode = 12;
            [t_vec_m, rv_ECI_m, maneuvers_dV, formation_fuel_level] = continuous_control(rv_ECI(:,end), consts, spacecraft, formation, mode);
            maneuvers_maintenance1 = [maneuvers_maintenance1, maneuvers_dV];
            formation.fuel_level = formation_fuel_level;
            rv_ECI = [rv_ECI, rv_ECI_m];
            t_vec = [t_vec; t_vec_m];        
            T = t_vec(end);
            quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);                                     
        end                
    end
    if sum(maneuvers_maintenance1,'all') ~= 0
        maneuvers_out = [maneuvers_out, sum(maneuvers_maintenance1,2)];
        formation_fuel_level_out = [formation_fuel_level_out, formation.fuel_level(:,end)];
    end
    Formation_state = [Formation_state; 2];
    T_event = [T_event; T];                
    
%% Stage 3. Image demonstration 1

    disp('Demonstration 1');
    options_precision = odeset('RelTol',1e-12,'AbsTol',1e-12);
    [t_out, rv_ECI_out] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), [T formation.demo_time(1,2)], rv_ECI(:,end), options_precision);
    rv_ECI_out = rv_ECI_out'; 
    rv_ECI = [rv_ECI, rv_ECI_out];
    t_vec = [t_vec; t_out];    
    T = t_vec(end);
    Formation_state = [Formation_state; 3];
    T_event = [T_event; t_out(1); t_out(end)];                

%% Stage 4. Formation flying with maintenance (up to reconfiguration)
   
    T_event = [T_event; T];                
    while T < formation.reconfiguration_time

        quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);

        maneuvers_maintenance1 = [];

        disp('Formation Flying');
        while quality == 1
        [t_vec_FF, rv_ECI_FF, te, ye, ie] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), [T T+100], rv_ECI(:,end), options_quality);
        rv_ECI_FF = rv_ECI_FF';
        rv_ECI = [rv_ECI, rv_ECI_FF];
        t_vec = [t_vec; t_vec_FF ];
        T = t_vec(end);
        quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);
        
        end
        if T < formation.reconfiguration_time && quality == 0                   
            disp('Orbit Maintenance');
            mode = 12;
            [t_vec_m, rv_ECI_m, maneuvers_dV, formation_fuel_level] = continuous_control(rv_ECI(:,end), consts, spacecraft, formation, mode);
            maneuvers_maintenance1 = [maneuvers_maintenance1, maneuvers_dV];
            formation.fuel_level = formation_fuel_level;
            rv_ECI = [rv_ECI, rv_ECI_m];
            t_vec = [t_vec; t_vec_m];        
            T = t_vec(end);
            quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);                                     
        end                
    end
    if sum(maneuvers_maintenance1,'all') ~= 0
        maneuvers_out = [maneuvers_out, sum(maneuvers_maintenance1,2)];
        formation_fuel_level_out = [formation_fuel_level_out, formation.fuel_level(:,end)];
    end
    Formation_state = [Formation_state; 2];
    T_event = [T_event; T];                

%% Stage 5. Reconfiguration (from first geometry to the second one)

    disp('Reconfiguration');
    if formation.reconfiguration_flag == 1
        
        formation.geometry = formation.geometry2;
        formation_geometry2 = formation.geometry;
        
    elseif formation.reconfiguration_flag == 2 
        
        % Calculating cost matrix in terms of spent fuel 
        for i = 1:formation.N_active_sats               
            spacecraft_wet_mass_updated = (spacecraft.dry_mass + formation.fuel_level(i,end))*exp(-Cost_matrix_dV(i,:)/spacecraft.thruster_Isp/consts.g);
            reconfiguration_matrix_fuel(i,:) = (spacecraft.dry_mass + formation.fuel_level(i,end))*ones(1, formation.N_active_sats) - spacecraft_wet_mass_updated;
        end

        % Solving assignment problem and assigning satellites to new set of reference trajectories
        [matchMatrix, ~] = maneuverAssignment(reconfiguration_matrix_fuel, formation.fuel_level(:,end));    

        for i = 1:(formation.N_sats-1)
            formation.geometry(:,matchMatrix(i,1)+1) = formation.geometry2(:,matchMatrix(i,2)+1);
        end
        formation_geometry2 = formation.geometry;
        
    end
            
    % Reconfiguration maneuvers 
    maneuvers_reconfiguraiton = [];
    T_event = [T_event; T];
    mode = 1;
    [t_vec_reconf, rv_ECI_reconf, maneuvers_dV, formation_fuel_level] = multisatellite_orbit_correction_3_impulse(rv_ECI(:,end), consts, spacecraft, formation, mode);
    [collision_flag, ISD_min] = collision_check(t_vec_reconf, rv_ECI_reconf, formation);                                               
    formation.fuel_level = formation_fuel_level;
    maneuvers_reconfiguraiton = [maneuvers_reconfiguraiton, maneuvers_dV];
    rv_ECI = [rv_ECI, rv_ECI_reconf];
    t_vec = [t_vec; t_vec_reconf + t_vec(end)];
    T = t_vec(end);

    mode = 11;
    [t_vec_out, rv_ECI_out, maneuvers_dV, formation_fuel_level] = continuous_control(rv_ECI(:,end), consts, spacecraft, formation, mode);
    maneuvers_reconfiguraiton = [maneuvers_reconfiguraiton, maneuvers_dV];
    formation.fuel_level = formation_fuel_level;
    t_vec = [t_vec; t_vec_out];
    rv_ECI = [rv_ECI, rv_ECI_out];
    T = t_vec(end);
    quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);

    disp(['Reconfiguration took ' num2str((t_vec(end) - formation.reconfiguration_time)/60) ' minutes , impulsive corrections: ' num2str(t_vec_reconf(end)/60) ' min, continuous control: ' num2str((t_vec_out(end) - t_vec_out(1))/60) ' min']);

    T_event = [T_event; T];
    maneuvers_out = [maneuvers_out, sum(maneuvers_reconfiguraiton,2)];
    formation_fuel_level_out = [formation_fuel_level_out, formation_fuel_level(:,end)];
    Formation_state = [Formation_state; 1];

    experimental_mode = 0;
    if experimental_mode == 1 
        reconfiguration_experiment(rv_ECI,consts, spacecraft, formation, reconfiguration_matrix_dV)
    end
            
%% Stage 6. Formation flying with maintenance (up to the seconds demo)

    T_event = [T_event; T];
    while T < formation.demo_time(2,1)
        quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);
        maneuvers_maintenance2 = [];

        disp('Formation Flying');
        while quality == 1
        [t_vec_FF, rv_ECI_FF, te, ye, ie] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), [T T+100], rv_ECI(:,end), options_quality);
        rv_ECI_FF = rv_ECI_FF';
        rv_ECI = [rv_ECI, rv_ECI_FF];
        t_vec = [t_vec; t_vec_FF ];
        T = t_vec(end);
        quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);
        end
        if T < formation.demo_time(2,1) && quality == 0
            disp('Orbit Maintenance');
            mode = 12;
            [t_vec_out, rv_ECI_out, maneuvers_dV, formation_fuel_level] = continuous_control(rv_ECI(:,end), consts, spacecraft, formation, mode);
            maneuvers_maintenance2 = [maneuvers_maintenance2, maneuvers_dV];
            formation.fuel_level = formation_fuel_level;
            t_vec = [t_vec; t_vec_out];
            rv_ECI = [rv_ECI, rv_ECI_out];
            T = t_vec(end);
        end
    end            
    maneuvers_out = [maneuvers_out, sum(maneuvers_maintenance2,2)];
    formation_fuel_level_out = [formation_fuel_level_out, formation_fuel_level(:,end)];
    Formation_state = [Formation_state; 2];
    T_event = [T_event; T];

%% Stage 7. Image demonstration 2
    disp('Demonstration 2');
    options_precision = odeset('RelTol',1e-12,'AbsTol',1e-12);
    [t_out, rv_ECI_out] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), [T formation.demo_time(2,2)], rv_ECI(:,end), options_precision);
    rv_ECI_out = rv_ECI_out'; 
    rv_ECI = [rv_ECI, rv_ECI_out];
    t_vec = [t_vec; t_out];    
    T = t_vec(end);
    Formation_state = [Formation_state; 3];
    T_event = [T_event; t_out(1); t_out(end)];
            
%% Stage 8. Formation flying with maintenance (up to the end of scenario)

    T_event = [T_event; T];
    while T < seconds(formation.final_orbit_epoch - formation.orbit_epoch)

        quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);
        maneuvers_maintenance2 = [];

        disp('Formation Flying');
        while quality == 1
        [t_vec_FF, rv_ECI_FF, te, ye, ie] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), [T T+100], rv_ECI(:,end), options_quality);
        rv_ECI_FF = rv_ECI_FF';
        rv_ECI = [rv_ECI, rv_ECI_FF];
        t_vec = [t_vec; t_vec_FF ];
        T = t_vec(end);
        quality = formation_quality(rv_ECI(:,end), consts, spacecraft, formation);
        end
        
        if T < seconds(formation.final_orbit_epoch - formation.orbit_epoch) && quality == 0
            disp('Orbit Maintenance');
            mode = 12;
            [t_vec_out, rv_ECI_out, maneuvers_dV, formation_fuel_level] = continuous_control(rv_ECI(:,end), consts, spacecraft, formation, mode);
            maneuvers_maintenance2 = [maneuvers_maintenance2, maneuvers_dV];
            formation.fuel_level = formation_fuel_level;
            t_vec = [t_vec; t_vec_out];
            rv_ECI = [rv_ECI, rv_ECI_out];
            T = t_vec(end);
        end
    end            
    maneuvers_out = [maneuvers_out, sum(maneuvers_maintenance2,2)];
    formation_fuel_level_out = [formation_fuel_level_out, formation_fuel_level(:,end)];
    Formation_state = [Formation_state; 2];
    T_event = [T_event; T];

    disp('Mission complete!');  

end   
