clear; clc;

X = 3833974.71158652;
Y = 1471085.80514079;
Z = 4864203.65318255;

a = 6378137;               
e = 0.081819190842622;       

lambda_deg = atan2d(Y, X); 

phi_deg_old = atan2d(Z, sqrt(X^2 + Y^2));


maxIter = 20;     
tol = 1e-10;       
phi_deg_new = phi_deg_old;

for i = 1:maxIter
    sin_phi = sind(phi_deg_new);
    numerator = Z + a*e^2*sin_phi / sqrt(1 - e^2*sin_phi^2);
    denominator = sqrt(X^2 + Y^2);
    phi_iter = atan2d(numerator, denominator);

    if abs(phi_iter - phi_deg_new) < tol
        break;
    end
    phi_deg_new = phi_iter;
end

phi_deg = phi_deg_new; 

sin_phi = sind(phi_deg);
N = a / sqrt(1 - e^2*sin_phi^2);  
h = sqrt(X^2 + Y^2)/cosd(phi_deg) - N;


fprintf('Wyniki metodą iteracyjną:\n');
fprintf('phi (szer. geogr.): %f [deg]\n', phi_deg);
fprintf('lambda (dl. geogr.): %f [deg]\n', lambda_deg);
fprintf('h (wysokosc): %f [m]\n', h);


try
    lla_matlab = ecef2lla([X, Y, Z]);
    fprintf('\nPorownanie z ecef2lla:\n');
    fprintf('phi (ecef2lla):    %f [deg]\n', lla_matlab(1));
    fprintf('lambda (ecef2lla): %f [deg]\n', lla_matlab(2));
    fprintf('h (ecef2lla):      %f [m]\n',   lla_matlab(3));
catch
    warning('Funkcja ecef2lla jest niedostepna - brak Aerospace Toolbox.');
end
