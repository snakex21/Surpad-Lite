satellites = [20200 , 0, 0; % Satelita 1
              -20200 , 0, 0; % Satelita 2
              0, 20200 , 0; % Satelita 3
              0, -20200 , 0; % Satelita 4
              15000,15000,0; % Satelita 5
              -15000,15000,0]; % Satelita 6
time_sent = [10000; 10000; 10000; 10000; 10000; 10000];                                 
delays = [0.067; 0.072; 0.070; 0.069; 0.071; 0.073];                                   
c = 299792.458;                                                           

fun = @(x) [
    sqrt((satellites(1,1)-x(1))^2 + (satellites(1,2)-x(2))^2 + (satellites(1,3)-x(3))^2) - c * (x(4) - time_sent(1) - delays(1));
    sqrt((satellites(2,1)-x(1))^2 + (satellites(2,2)-x(2))^2 + (satellites(2,3)-x(3))^2) - c * (x(4) - time_sent(2) - delays(2));
    sqrt((satellites(3,1)-x(1))^2 + (satellites(3,2)-x(2))^2 + (satellites(3,3)-x(3))^2) - c * (x(4) - time_sent(3) - delays(3));
    sqrt((satellites(4,1)-x(1))^2 + (satellites(4,2)-x(2))^2 + (satellites(4,3)-x(3))^2) - c * (x(4) - time_sent(4) - delays(4));
    sqrt((satellites(5,1)-x(1))^2 + (satellites(5,2)-x(2))^2 + (satellites(5,3)-x(3))^2) - c * (x(4) - time_sent(5) - delays(5));
    sqrt((satellites(6,1)-x(1))^2 + (satellites(6,2)-x(2))^2 + (satellites(6,3)-x(3))^2) - c * (x(4) - time_sent(6) - delays(6))
];

initial_guess = [0 , 0 , 0 , 0]; 


options = optimoptions('lsqnonlin', 'Display', 'off');
solution = lsqnonlin( fun , initial_guess , [] , [] , options );


fprintf ('Pozycja odbiornika GPS ( ECEF ): X = %.2f km , Y = %.2f km , Z = %.2f km\n', solution(1) , solution(2) , solution(3) );
fprintf ('Czas odbioru sygnalu : %.4f sekund \n', solution(4) );
[solution, resnorm, residual, exitflag, output] = lsqnonlin(fun, initial_guess, [], [], options);

fprintf('resnorm = %g\n', resnorm);
fprintf('Liczba iteracji: %d\n', output.iterations);

