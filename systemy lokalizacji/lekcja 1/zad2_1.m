phi1 = 52.0001;    
lambda1 = 21.0001;  
phi2 = 51.0002;    
lambda2 = 22.0003;  
phi1_rad = deg2rad(phi1);
lambda1_rad = deg2rad(lambda1);
phi2_rad = deg2rad(phi2);
lambda2_rad = deg2rad(lambda2);
R = 6371;
delta_phi   = phi2_rad - phi1_rad;
delta_lambda = lambda2_rad - lambda1_rad;
a = sin(delta_phi / 2).^2 + cos(phi1_rad) * cos(phi2_rad) * sin(delta_lambda / 2).^2;
c = 2 * atan2( sqrt(a), sqrt(1 - a) );
dH = R * c;
fprintf('Odległość wg wzoru Haversine wynosi: %.4f km\n', dH);
