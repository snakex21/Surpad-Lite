delays = [0.067; 0.072; 0.070; 0.069];
c = 299792.458;                         

distances = c * delays;

for i = 1:4
    fprintf('Odległość do satelity %d: %.2f km\n', i, distances(i));
end