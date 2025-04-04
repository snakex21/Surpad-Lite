phi_A    = deg2rad(48.5074); 
lambda_A = deg2rad(2.1278); 

phi_B    = deg2rad(48.8566);
lambda_B = deg2rad(2.3522); 

alpha_A = deg2rad(45);
alpha_B = deg2rad(90);

R = 6371;

delta_lambda = lambda_B - lambda_A;

d_AB = acos( sin(phi_A)*sin(phi_B) + cos(phi_A)*cos(phi_B)*cos(delta_lambda) ) * R;

theta = alpha_A - alpha_B;

distance_A = d_AB * tan(theta);

latitude  = phi_A + distance_A / R;
longitude = lambda_A + (distance_A / R) * cos(latitude);

fprintf('Twoje współrzędne:\n');
fprintf('Szerokość geogr.: %.6f°\n', rad2deg(latitude));
fprintf('Długość geogr.:   %.6f°\n', rad2deg(longitude));
