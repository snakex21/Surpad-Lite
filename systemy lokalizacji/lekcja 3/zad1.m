d = 20000;          
c = 299792.458;    

t = d / c;

t_micro = t * 1e6;

fprintf('Czas opóźnienia: %.6f s\n', t);
fprintf('Czas opóźnienia: %.2f µs\n', t_micro);