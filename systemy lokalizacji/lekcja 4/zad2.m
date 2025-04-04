X = 3833974.71158652;
Y = 1471085.80514079;
Z = 4864203.65318255;

[phi, lambda, height] = ecef_to_lla(X, Y, Z);

disp([phi, lambda, height]);
