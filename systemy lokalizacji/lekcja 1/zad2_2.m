phi1 = 50.01306942311383;   
lambda1 = 20.987243290265337;

phi2 = 64.14206537271572;  
lambda2 = -21.92696230009716; 

R = 6371;

googleDist_m = 2949.80;

phi1_rad    = deg2rad(phi1);
lambda1_rad = deg2rad(lambda1);
phi2_rad    = deg2rad(phi2);
lambda2_rad = deg2rad(lambda2);

delta_phi    = phi2_rad - phi1_rad;
delta_lambda = lambda2_rad - lambda1_rad;

dH_km = 2 * R * asin( sqrt( sin(delta_phi/2).^2 ...
        + cos(phi1_rad)*cos(phi2_rad)*sin(delta_lambda/2).^2 ) );
dH_m = dH_km * 1000;

fprintf('\n========================================\n');
fprintf('       POMIAR ODLEGLOSCI - WYNIKI       \n');
fprintf('========================================\n\n');

fprintf('Punkt poczatkowy:\n');
fprintf('  Phi1    = %.5f°  (szerokosc)\n', phi1);
fprintf('  Lambda1 = %.5f°  (dlugosc)\n', lambda1);

fprintf('\nPunkt docelowy:\n');
fprintf('  Phi2    = %.5f°  (szerokosc)\n', phi2);
fprintf('  Lambda2 = %.5f°  (dlugosc)\n', lambda2);

fprintf('\nPrzyjety promien Ziemi: %.0f km\n', R);

fprintf('\n----------------------------------------\n');
fprintf('Odleglosc wg Google Maps: %.2f m\n', googleDist_m);
fprintf('Odleglosc wg Haversine  : %.2f m\n', dH_m);
fprintf('----------------------------------------\n');

diff_m = dH_m - googleDist_m;
fprintf('Roznica (Haversine - Google Maps) = %.2f m\n\n', diff_m);
