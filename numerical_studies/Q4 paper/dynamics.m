% script simulates dynamics of two and three formation flying satellites
clear all;
consts = startup_formation_control();
global environment
environment = 'J2';

% The target orbit is SSO whose orbital plane intersects with 
% terminator line at equator
orbit_epoch = datetime(2021, 04, 12, 0, 0, 0);
oe(1) = consts.rEarth + 726e3;
oe(2) = 0;
oe(3) = deg2rad(98.29);
oe(4) = deg2rad(290.24);
oe(5) = 0;
oe(6) = deg2rad(63.93);

target_orbit_rv = oe2rv(oe, consts);
spacecraft = 0;
radius_relative_orbit = 1000; % meters
% corresponding GCO orbit
c1 = radius_relative_orbit;
c2 = sqrt(3)/2*radius_relative_orbit;
alpha1 = 0;
alpha2 = pi;
formation_geometry(:,1) = [0;0;0;0];
formation_geometry(:,2) = [c1;c2;0;alpha1];
formation_geometry(:,3) = [c1;c2;0; alpha2];


rv_orb = get_rv_from_analytic_HCW_solution(target_orbit_rv, formation_geometry, consts);

for i = 1:size(rv_orb,2)
    rv_ECI(i*6-5:i*6,1) = orb2ECI(target_orbit_rv, rv_orb(:,i), consts);
end

options_precision = odeset('RelTol',1e-12,'AbsTol',1e-12);
t_span = 1:1:consts.day2sec;
[t_out, rv_ECI_out] = ode45(@(t, rv) rhs_Formation_inertial(t, rv, consts, spacecraft), t_span, rv_ECI, options_precision);
rv_ECI_out = rv_ECI_out'; 
rv_ECI = rv_ECI_out;
t_vec = t_out;    

for j = 1:size(rv_ECI,2)

    for i = 1:3
        rv_orb_final(:,i,j) = ECI2orb(rv_ECI(1:6,j), rv_ECI(6*i-5:6*i,j), consts);
    end
end

for i = 1:3
    plot3(rv_orb_final(1,i,1), rv_orb_final(2,i,1), rv_orb_final(3,i,1), 'sk');
    hold on;
    xlabel('x, m');
    xlabel('y, m');
    xlabel('z, m');
end

formation_flying_animation(rv_orb_final(:,:,1:6000), rv_orb(:,:,1:size(rv_orb,3)/3), 'off', 'Formation_Sats_Dynamics');


