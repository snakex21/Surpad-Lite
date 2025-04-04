clc; clear; close all;

%% -------------------- (1) Wczytanie danych z pliku lub "z ręki" --------------------

filename = 'satelityGPS.csv';

if ~isfile(filename)
    fprintf('Plik %s nie istnieje. \n', filename);
    choice = input('Czy chcesz wprowadzić dane z ręki? (T/N) ', 's');
    if upper(choice) == 'T'
        xs = zeros(4,1);
        ys = zeros(4,1);
        zs = zeros(4,1);
        ds = zeros(4,1);
        
        for i = 1:4
            fprintf('Podaj współrzędne i odległość dla satelity nr %d:\n', i);
            xs(i) = input('   x = ');
            ys(i) = input('   y = ');
            zs(i) = input('   z = ');
            ds(i) = input('   d = ');
        end
        numSats = 4;
    else
        error('Brak pliku z danymi i brak wprowadzonych danych. Zakończono.');
    end
else
    data = readmatrix(filename);
    xs = data(:,1);
    ys = data(:,2);
    zs = data(:,3);
    ds = data(:,4);
    numSats = length(xs);
end

if numSats < 4
    error('Potrzebujesz co najmniej 4 satelitów do wyznaczenia pozycji GPS!');
end

%% -------------------- (2) Sprawdzanie współpłaszczyznowości satelitów --------------------
basePoint = [xs(1), ys(1), zs(1)];
vectors = zeros(numSats-1, 3);
for i = 2:numSats
    vectors(i-1, :) = [xs(i), ys(i), zs(i)] - basePoint;
end

rankVectors = rank(vectors);

if rankVectors < 3
    warning('Uwaga! Satelity są (w praktyce) współpłaszczyznowe. Rozwiązanie może być niestabilne lub niemożliwe.');
end

%% -------------------- (3) Dodawanie losowego szumu do pomiarów --------------------
noiseLevel = 50; 
ds = ds + randn(size(ds)) * noiseLevel;

%% -------------------- (4) Testowanie wpływu liczby satelitów --------------------
fullPositions = cell(numSats-3,1); 
baseError = [];

for n = 4:numSats
    subset_x = xs(1:n);
    subset_y = ys(1:n);
    subset_z = zs(1:n);
    subset_d = ds(1:n);

    X_est = lsmPosition(subset_x, subset_y, subset_z, subset_d);
    fullPositions{n-3} = X_est;

end

%% -------------------- (Główne obliczenie) -----------------------------------------
Xfinal = lsmPosition(xs, ys, zs, ds);

fprintf('\n----------------------------------------\n');
fprintf('Wyznaczona pozycja (LSM) na podstawie wszystkich %d satelitów:\n', numSats);
fprintf(' X = %.3f \n Y = %.3f \n Z = %.3f \n', Xfinal(1), Xfinal(2), Xfinal(3));
fprintf('----------------------------------------\n');

%% -------------------- Wizualizacja 3D --------------------
figure; hold on; grid on; axis equal;
xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title('Wizualizacja pozycji GPS metodą LSM');
scatter3(xs, ys, zs, 100, 'r', 'filled');
text(xs, ys, zs, arrayfun(@(i) sprintf('S%d', i), 1:numSats, 'UniformOutput', false), ...
    'VerticalAlignment','bottom','HorizontalAlignment','right');
scatter3(Xfinal(1), Xfinal(2), Xfinal(3), 100, 'b', 'filled');
text(Xfinal(1), Xfinal(2), Xfinal(3), 'Odbiornik', ...
    'VerticalAlignment','bottom','HorizontalAlignment','left');
view(3); rotate3d on;
hold off;

function X_est = lsmPosition(xs, ys, zs, ds)

    numSatsLocal = length(xs);
    A = zeros(numSatsLocal - 1, 3);
    b = zeros(numSatsLocal - 1, 1);

    for i = 2:numSatsLocal
        A(i-1, 1) = xs(i) - xs(1);
        A(i-1, 2) = ys(i) - ys(1);
        A(i-1, 3) = zs(i) - zs(1);

        b(i-1) = 0.5 * ( (ds(1)^2 - ds(i)^2) ...
                       - (xs(1)^2 - xs(i)^2) ...
                       - (ys(1)^2 - ys(i)^2) ...
                       - (zs(1)^2 - zs(i)^2) );
    end

    X_relative = (A' * A) \ (A' * b);
    X_est = X_relative + [xs(1); ys(1); zs(1)];
end
