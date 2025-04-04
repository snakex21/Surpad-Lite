x1 = 100;  y1 = 200;  
x2 = 300;  y2 = 250;  

theta1_deg = 30;  
theta2_deg = 60; 

theta1 = deg2rad(theta1_deg);
theta2 = deg2rad(theta2_deg);

tan_t1 = tan(theta1);
tan_t2 = tan(theta2);

x_ = ( (y1 - y2) + x2*tan_t2 - x1*tan_t1 ) / (tan_t2 - tan_t1);
y_ = ( y1*tan_t2 - y2*tan_t1 - (x1 - x2)*tan_t1*tan_t2 ) / (tan_t2 - tan_t1);

fprintf('Wyznaczona pozycja metodą resekcji:\n');
fprintf('x = %.2f\n', x_);
fprintf('y = %.2f\n', y_);
