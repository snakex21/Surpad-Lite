phi1 = 52;    
lambda1 = 21;  
phi2 = 51;  
lambda2 = 22; 

phi1_rad = deg2rad(phi1);
lambda1_rad = deg2rad(lambda1);
phi2_rad = deg2rad(phi2);
lambda2_rad = deg2rad(lambda2);

delta_lambda = lambda2_rad - lambda1_rad;

azymut_rad = atan2( sin(delta_lambda)*cos(phi2_rad), ...
    cos(phi1_rad)*sin(phi2_rad) - sin(phi1_rad)*cos(phi2_rad)*cos(delta_lambda) );

azymut_deg = rad2deg(azymut_rad);

if azymut_deg < 0
    azymut_deg = azymut_deg + 360;
end

fprintf('Azymut wynosi: %.4f stopni\n', azymut_deg);