function [Xr, Yr, Zr, delta_t] = pseudorange_to_ecef(P, sat_positions)

    c = 299792458; 


    fun = @(x) sum( ...
        ( sqrt( (x(1) - sat_positions(:,1)).^2 ...
               + (x(2) - sat_positions(:,2)).^2 ...
               + (x(3) - sat_positions(:,3)).^2 ) ...
          + c*x(4) - P' ).^2 );

    x0 = [mean(sat_positions(:,1)), ...
          mean(sat_positions(:,2)), ...
          mean(sat_positions(:,3)), ...
          0];

    options = optimset('Display', 'off');
    solution = fminsearch(fun, x0, options);
    
    Xr = solution(1);
    Yr = solution(2);
    Zr = solution(3);
    delta_t = solution(4);
end
