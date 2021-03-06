function rv_prime = rhs_Formation_LQR(T_local, rv, consts, spacecraft, formation)

    global K
    
    z_orb = rv(1:3) / norm(rv(1:3));
    y_orb = cross(rv(1:3), rv(4:6));
    y_orb = y_orb(1:3) / norm(y_orb(1:3));
    x_orb = cross(y_orb, z_orb);
    orb2ECI_matrix = [x_orb y_orb z_orb];
    
    rv_orb_desired = get_rv_from_analytic_HCW_solution(rv(1:6), formation.geometry, consts);
    rv_orb_desired = reshape(rv_orb_desired, [formation.N_sats*6 1]);

    for i = 1:formation.N_sats
        rv_orb_current(i*6-5:i*6,1) = ECI2orb(rv(1:6), rv(i*6-5:i*6), consts);
    end

    e = rv_orb_current - rv_orb_desired;
    
    for i = 1:formation.N_sats
        u_orb = K*e(i*6-5:i*6);
        if u_orb == 0
            u_orb = zeros(3,1);
        elseif norm(u_orb) > spacecraft.unit_thrust
            u_orb = u_orb./norm(u_orb)*spacecraft.unit_thrust;
        end
        
        u_ECI(:,i) = orb2ECI_matrix*u_orb;
%         u_ECI(:,i) = [0;0;0];
    end
    
    u_control = [zeros(3,formation.N_sats); u_ECI];

    N_sats = length(rv)/6;
    rv = reshape(rv, [6,N_sats]);
    r_prime = [rv(4:6,:); zeros(3,N_sats)];
    r_norm = vecnorm(rv(1:3,:));

    % Central gravity field
    A_cg = [zeros(3,N_sats); -consts.muEarth./(r_norm.^3).*rv(1:3,:)];

    R = consts.rEarth_equatorial;
    J2 = consts.J2;
    mu = consts.muEarth;
    delta = 3/2*J2*mu*R^2;
    
    % J2 perturbation
    A_j2 = delta./(r_norm.^5).*rv(1:3,:).*(5*rv(3,:).^2./r_norm.^2 - 1) - 2*delta./r_norm.^5.*[zeros(1,N_sats);zeros(1,N_sats);rv(3,:)];
    A_j2 = [zeros(3,N_sats); A_j2];

    rv_prime = r_prime + A_cg + A_j2 - u_control;
    
    rv_prime = reshape(rv_prime, [6*N_sats,1]);

end