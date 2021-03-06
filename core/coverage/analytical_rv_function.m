function rv = analytical_rv_function(oe, dim, consts)
%% Readme 

% Author: Shamil Biktimirov
% Date: September 21, 2021

% The script builds analytical function for position(t) and velocity(t) for
% an orbital motion

% For more details on the algorithm derivation please refer to the book "Curtis H. Orbital mechanics for engineering
% students. – Butterworth-Heinemann, 2013, chapters 2,3"

% Input: classical orbital elements [a[dim], e[-], i[rad], RAAN[rad], AOP[rad], MA[rad]]

% Output: [r(t); v(t)] - vector function describing position and velocity
% in corresponding dimensions

global environment

syms t positive

a = oe(1);
e = oe(2);
i = oe(3);
RAAN = oe(4);
AOP = oe(5);
MA = oe(6);

%% Step 1. Position and velocity vector in perifocal plane
% TA - true anomaly,
% n - mean motion,
% E - eccentric anomaly

switch dim
    case 'm, s'
        mu = consts.muEarth;
        rEarth_equatorial = consts.rEarth_equatorial;
    case 'km, s'
        mu = consts.muEarth / (1e3^3);
        rEarth_equatorial = consts.rEarth_equatorial / 1000;
    case 'AU, d'
        mu = consts.muSun / (consts.AstronomicUnit^3) * (consts.day2sec^2);
end   
n = sqrt(mu / a^3);
MA = mod(MA + n * t, 2*pi);

E = MA + e * sin(MA) + e^2 / 2 * sin(2 * MA) + e^3 / 8 * (3 * sin(3 * MA) - sin(MA));
TA = 2 * atan(sqrt((1 + e) / (1 - e)) * tan(E / 2));

r_perifocal = a * (1 - e^2) / (1 + e * cos(TA)) * [cos(TA); sin(TA); 0];
v_perifocal = sqrt(mu / (a * (1 - e^2))) * [-sin(TA); e + cos(TA); 0];

%% Step 2. Deriving a funtion r(t) and v(t) in ECI coordinates

switch environment 
    
    case 'J2'       
    C = 3 / 2 * (sqrt(mu) * consts.J2 * rEarth_equatorial^2);
    RAAN_dot =  - C / ((1 - e^2)^2 * a^(7/2)) * cos(i);
    AOP_dot = - C / ((1 - e^2)^2 * a^(7/2)) * (5/2 * sin(i)^2 - 2);
    AOP = AOP + AOP_dot * t;
    RAAN = RAAN + RAAN_dot * t;

end
    
M1 = [cos(AOP), sin(AOP), 0
    -sin(AOP), cos(AOP), 0
    0, 0, 1];

M2 = [1, 0, 0
    0, cos(i), sin(i)
    0, -sin(i), cos(i)];

M3 = [cos(RAAN), sin(RAAN),0
    -sin(RAAN), cos(RAAN), 0
    0, 0, 1];

Rotation_matrix = M1 * M2 * M3;
Rotation_matrix = Rotation_matrix';

r = Rotation_matrix * r_perifocal;   
v = Rotation_matrix * v_perifocal;
rv = [r; v];

end