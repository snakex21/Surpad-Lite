clear; clc;

lat_input = 50.06143;  
lon_input = 19.93658;  
h_input   = 219;       

fprintf('Punkt wejsciowy (LLA):\n');
fprintf('Lat = %.5f deg, Lon = %.5f deg, Alt = %.2f m\n\n', ...
    lat_input, lon_input, h_input);

XYZ = lla2ecef([lat_input, lon_input, h_input]);
X = XYZ(1);  Y = XYZ(2);  Z = XYZ(3);

fprintf('Wynik lla2ecef (ECEF):\n');
fprintf('X = %.3f m, Y = %.3f m, Z = %.3f m\n\n', X, Y, Z);


LLA_back = ecef2lla([X, Y, Z]);
lat_back = LLA_back(1);
lon_back = LLA_back(2);
h_back   = LLA_back(3);

fprintf('Wynik odwrotny ecef2lla (powrot do LLA):\n');
fprintf('Lat = %.5f deg, Lon = %.5f deg, Alt = %.2f m\n\n', ...
    lat_back, lon_back, h_back);

dLat = lat_back - lat_input;
dLon = lon_back - lon_input;
dH   = h_back   - h_input;

fprintf('Roznice:\n');
fprintf('Delta lat = %.6f deg\n', dLat);
fprintf('Delta lon = %.6f deg\n', dLon);
fprintf('Delta alt = %.6f m\n',   dH);

fprintf('https://www.google.com/maps/place/%.6f,%.6f\n', lat_back, lon_back);
