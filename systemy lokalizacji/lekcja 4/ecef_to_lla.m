function [lat_deg, lon_deg, h] = ecef_to_lla(X, Y, Z)

    a = 6378137;                  
    e = 0.081819190842622;        


    lon_deg = atan2d(Y, X);

    phi_deg = atan2d(Z, sqrt(X^2 + Y^2));

    maxIter = 20;
    tol = 1e-10;
    for i = 1:maxIter
        sin_phi = sind(phi_deg);
        numerator   = Z + a*e^2*sin_phi / sqrt(1 - e^2*sin_phi^2);
        denominator = sqrt(X^2 + Y^2);
        phi_new = atan2d(numerator, denominator);
        if abs(phi_new - phi_deg) < tol
            break;
        end
        phi_deg = phi_new;
    end

    sin_phi = sind(phi_deg);
    N = a / sqrt(1 - e^2*sin_phi^2);
    h = sqrt(X^2 + Y^2)/cosd(phi_deg) - N;

    lat_deg = phi_deg;
end
