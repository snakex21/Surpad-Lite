clear; clc;

P = [20214676.4739585, 23832938.0640297, 24756020.0391083, ...
     25505017.9518568, 28928636.879954,  29793456.3362523];

sat_positions = [
   15600000, 7540000, 20140000;
   19170000, 6100000, 22510000;
   17610000, 3200000, 25360000;
   19170000, 2200000, 25230000;
   21000000, 4100000, 28000000;
   22000000, 6200000, 28000000
];


[Xr, Yr, Zr, delta_t] = pseudorange_to_ecef(P, sat_positions);

disp('========== Wyniki rozwiazania pseudorange ==========');
fprintf('Xr = %.3f m\n', Xr);
fprintf('Yr = %.3f m\n', Yr);
fprintf('Zr = %.3f m\n', Zr);
fprintf('delta_t = %.6e s (blad zegara)\n\n', delta_t);


[lat_deg, lon_deg, alt] = ecef_to_lla(Xr, Yr, Zr);
disp('========== Konwersja ECEF -> LLA ==========');
fprintf('Lat = %.6f deg\n', lat_deg);
fprintf('Lon = %.6f deg\n', lon_deg);
fprintf('Alt = %.2f m\n', alt);


fprintf('\nLink do Google Maps:\n');
fprintf('https://www.google.com/maps/place/%.6f,%.6f\n', lat_deg, lon_deg);
