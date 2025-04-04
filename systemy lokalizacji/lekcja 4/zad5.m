Fs = 1;
refFrame = "NED";
lla0 = [42.2825, -71.343, 53.0352];
N = 100;

time = (0:N-1)' / Fs;
pos = zeros(N, 3);  
vel = zeros(N, 3);  

gps = gpsSensor("SampleRate", Fs, "ReferenceLocation", lla0, "ReferenceFrame", refFrame);
gnss = gnssSensor("SampleRate", Fs, "ReferenceLocation", lla0, "ReferenceFrame", refFrame);

[llaGPS, velGPS] = gps(pos, vel);

figure;
subplot(3, 1, 1);
plot(time, llaGPS(:,1));
title('Latitude (GPS)');
ylabel('degrees');
xlabel('s');

subplot(3, 1, 2);
plot(time, llaGPS(:,2));
title('Longitude (GPS)');
ylabel('degrees');
xlabel('s');

subplot(3, 1, 3);
plot(time, llaGPS(:,3));
title('Altitude (GPS)');
ylabel('m');
xlabel('s');

figure;
plot(time, velGPS);
title('Velocity (GPS)');
ylabel('m/s');
xlabel('s');
legend('North', 'East', 'Down');

[llaGNSS, velGNSS] = gnss(pos, vel);

figure;
subplot(3, 1, 1);
plot(time, llaGNSS(:,1));
title('Latitude (GNSS)');
ylabel('degrees');
xlabel('s');

subplot(3, 1, 2);
plot(time, llaGNSS(:,2));
title('Longitude (GNSS)');
ylabel('degrees');
xlabel('s');

subplot(3, 1, 3);
plot(time, llaGNSS(:,3));
title('Altitude (GNSS)');
ylabel('m');
xlabel('s');

rng('default');  
initTime = datetime(2020, 4, 20, 18, 10, 0, "TimeZone", "America/New_York");
gnss = gnssSensor("SampleRate", Fs, "ReferenceLocation", lla0, "ReferenceFrame", refFrame, "InitialTime", initTime);
[~, ~, status] = gnss(pos, vel);

hdops = vertcat(status.HDOP);
figure;
plot(time, hdops);
title('HDOP');
ylabel('Value');
xlabel('s');

satAz = status(1).SatelliteAzimuth;
satEl = status(1).SatelliteElevation;
figure;
skyplot(satAz, satEl);
title(sprintf('Satellites in view: %d\nHDOP: %.4f', numel(satAz), hdops(1)));