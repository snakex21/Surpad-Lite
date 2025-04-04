clear; clc; close all;

disp('1. Konfiguracja parametrów symulacji...');

startTime = datetime(2025, 3, 26, 12, 0, 0, 'TimeZone', 'Europe/Warsaw');
disp(['   Czas startowy: ', datestr(startTime)]);

simulationSteps = 100;       
dt = 1;                      
stopTime = startTime + seconds((simulationSteps - 1) * dt); 
maskAngle = 5;               
rinexFile = "GODS00USA_R_20211750000_01D_GN.rnx"; 

lla0 = [50.01535297698229, 20.990800015260064, 0]; 
disp(['   Pozycja początkowa (LLA): ', num2str(lla0)]);

routePointsLLA = [
    50.01535297698229, 20.990800015260064, 0; 
    50.01657234092592, 20.991124320438843, 0;
    50.0169722179755, 20.991251413008907, 0;
    50.01726226755582, 20.991321533047557, 0;
    50.0173889877092,  20.99005937236555,  0;
    50.0166849826976,  20.989866542259247, 0;
    50.01661739767381,  20.99072989523518, 0
];
disp(['   Liczba punktów trasy: ', num2str(size(routePointsLLA, 1))]);

disp('2. Generowanie symulowanej trasy...');

routePointsNED = lla2ned(routePointsLLA, lla0, 'ellipsoid');

recPos = zeros(simulationSteps, 3); 
recVel = zeros(simulationSteps, 3); 

numSegments = size(routePointsNED, 1) - 1;
segmentLengths = zeros(numSegments, 1);
for k = 1:numSegments
    segmentLengths(k) = norm(routePointsNED(k+1, :) - routePointsNED(k, :));
end
totalLength = sum(segmentLengths);
totalTime = simulationSteps * dt;


if totalLength < eps 
    disp('   Punkty trasy są zbyt blisko siebie lub identyczne. Odbiornik pozostanie w punkcie startowym.');
    for idx = 1:simulationSteps
        recPos(idx, :) = routePointsNED(1, :); 
        recVel(idx, :) = [0, 0, 0];
    end
else
    speed = totalLength / totalTime;
    disp(['   Obliczona stała prędkość: ', num2str(speed), ' m/s']);

    timePerSegment = segmentLengths / speed;
    
    cumulativeTime = [0; cumsum(timePerSegment)];
    currentTime = 0;
    for idx = 1:simulationSteps
        currentTime = (idx - 1) * dt;

        segmentIdx = find(currentTime >= cumulativeTime(1:end-1) & currentTime < cumulativeTime(2:end), 1, 'first');
       
        if isempty(segmentIdx) && currentTime >= cumulativeTime(end)
           segmentIdx = numSegments; 
        elseif isempty(segmentIdx)
            warning('Nie można znaleźć segmentu dla czasu %f. Używanie pierwszego segmentu.', currentTime);
            segmentIdx = 1; 
        end

        p_start = routePointsNED(segmentIdx, :);
        p_end = routePointsNED(segmentIdx + 1, :);

        timeInSegment = currentTime - cumulativeTime(segmentIdx);
        
        currentSegmentDuration = timePerSegment(segmentIdx);

        if currentSegmentDuration > eps 
           fraction = timeInSegment / currentSegmentDuration;
           fraction = max(0, min(1, fraction)); 
           recPos(idx, :) = p_start + (p_end - p_start) * fraction;
        else
           recPos(idx, :) = p_start; 
        end
        
        if currentSegmentDuration > eps
            recVel(idx, :) = (p_end - p_start) / currentSegmentDuration;
        else
            recVel(idx, :) = [0, 0, 0];
        end
    end
    recPos(simulationSteps, :) = routePointsNED(end, :);
    if timePerSegment(end) > eps
       recVel(simulationSteps, :) = (routePointsNED(end, :) - routePointsNED(end-1,:)) / timePerSegment(end);
    else
       recVel(simulationSteps, :) = [0,0,0]; 
    end
end

receiverLLA = ned2lla(recPos, lla0, 'ellipsoid');
disp('   Wygenerowano trajektorię odbiornika.');

disp('3. Symulacja konstelacji satelitów...');

sc = satelliteScenario(startTime, stopTime, dt);

try
    navmsg = rinexread(rinexFile);
    disp(['   Wczytano plik RINEX: ', rinexFile]);
catch ME
    error('Nie można wczytać pliku RINEX: %s\n%s', rinexFile, ME.message);
end

satellite(sc, navmsg);

satID = sc.Satellites.Name;
numSats = numel(sc.Satellites);
disp(['   Liczba satelitów w scenariuszu: ', num2str(numSats)]);

allSatPos = zeros(numSats, 3, simulationSteps); 
allSatVel = zeros(numSats, 3, simulationSteps); 

disp('   Pobieranie pozycji i prędkości satelitów...');
for i = 1:numSats

    [oneSatPos, oneSatVel] = states(sc.Satellites(i), "CoordinateFrame", "ecef");
    allSatPos(i, :, :) = permute(oneSatPos, [3, 1, 2]);
    allSatVel(i, :, :) = permute(oneSatVel, [3, 1, 2]);
end
disp('   Zakończono pobieranie danych satelitów.');

disp('4. Obliczanie pseudoodległości i widoczności satelitów...');

allP = zeros(numSats, simulationSteps);
allPDot = zeros(numSats, simulationSteps);
allIsSatVisible = false(numSats, simulationSteps);

figure;
sp = skyplot([], [], 'MaskElevation', maskAngle);
title('Widoczność satelitów (Skyplot)');

for idx = 1:simulationSteps
    satPos = allSatPos(:, :, idx);
    satVel = allSatVel(:, :, idx);
    currentReceiverLLA = receiverLLA(idx, :);
    currentRecVel = recVel(idx, :);
    [satAz, satEl, currentIsSatVisible] = lookangles(currentReceiverLLA, satPos, maskAngle);
    allIsSatVisible(:, idx) = currentIsSatVisible;
    [xECEF, yECEF, zECEF] = latlon2ecef(currentReceiverLLA(1), currentReceiverLLA(2), currentReceiverLLA(3));
    currentRecVelECEF = ned2ecefv(currentRecVel(1), currentRecVel(2), currentRecVel(3), currentReceiverLLA(1), currentReceiverLLA(2));

    [currentP, currentPDot] = pseudoranges(currentReceiverLLA, satPos, currentRecVelECEF, satVel);
    allP(:, idx) = currentP;
    allPDot(:, idx) = currentPDot;
    visibleIdx = currentIsSatVisible;
    set(sp, 'AzimuthData', satAz(visibleIdx), ...
            'ElevationData', satEl(visibleIdx), ...
            'LabelData', satID(visibleIdx));
    title(sp, ['Widoczność satelitów (Krok: ', num2str(idx), '/', num2str(simulationSteps), ')']);
    drawnow limitrate; 
end
disp('   Zakończono obliczanie pseudoodległości.');

disp('5. Szacowanie pozycji odbiornika...');

lla = zeros(simulationSteps, 3);
gnssVel = zeros(simulationSteps, 3);
hdop = zeros(simulationSteps, 1);    
vdop = zeros(simulationSteps, 1);    

for idx = 1:simulationSteps
    p = allP(:, idx);
    pdot = allPDot(:, idx);
    isSatVisible = allIsSatVisible(:, idx);
    satPos = allSatPos(:, :, idx);
    satVel = allSatVel(:, :, idx);

    if sum(isSatVisible) < 4
        warning('Krok %d: Mniej niż 4 widoczne satelity (%d). Nie można obliczyć pozycji.', idx, sum(isSatVisible));
        if idx > 1
            lla(idx, :) = lla(idx-1, :);
            gnssVel(idx, :) = gnssVel(idx-1, :);
            hdop(idx) = NaN;
            vdop(idx) = NaN;
        else
            lla(idx, :) = [NaN, NaN, NaN];
            gnssVel(idx, :) = [NaN, NaN, NaN];
            hdop(idx) = NaN;
            vdop(idx) = NaN;
        end
        continue; 
    end

[currentLla, currentGnssVel, currentHdop, currentVdop] = receiverposition( ...
    p(isSatVisible), ...
    satPos(isSatVisible, :), ...
    pdot(isSatVisible), ...
    satVel(isSatVisible, :) ...
);

    lla(idx, :) = currentLla;
    gnssVel(idx, :) = currentGnssVel;
    hdop(idx) = currentHdop;
    vdop(idx) = currentVdop;
end
disp('   Zakończono szacowanie pozycji.');

disp('6. Wizualizacja wyników...');

figure;
geoplot(receiverLLA(:, 1), receiverLLA(:, 2), 'b.-');
hold on;
geoplot(lla(:, 1), lla(:, 2), 'r.-'); 
geobasemap('streets'); 
legend('Trasa rzeczywista (Ground Truth)', 'Trasa estymowana (GNSS)', 'Location', 'best');
title('Porównanie trasy rzeczywistej i estymowanej');
grid on;

estPosNED = lla2ned(lla, lla0, 'ellipsoid');

posErrorNED = estPosNED - recPos; 

winSize = floor(simulationSteps / 10); 
if winSize < 1, winSize = 1; end
smoothedErrorNED = smoothdata(abs(posErrorNED), 1, 'movmedian', winSize);

figure;
plot(1:simulationSteps, smoothedErrorNED(:, 1), 'r', 'LineWidth', 1.5); 
hold on;
plot(1:simulationSteps, smoothedErrorNED(:, 2), 'g', 'LineWidth', 1.5); 
plot(1:simulationSteps, smoothedErrorNED(:, 3), 'b', 'LineWidth', 1.5); 

legend('Błąd E (wschód)', 'Błąd N (północ)', 'Błąd U (góra)'); 
legend('Błąd N (północ)', 'Błąd E (wschód)', 'Błąd D (dół)');
xlabel('Krok symulacji (czas w sekundach)');
ylabel('Wygładzony błąd absolutny [m]');
title('Błąd estymacji pozycji w układzie NED');
grid on;

figure;
plot(1:simulationSteps, hdop, 'm.-', 'DisplayName', 'HDOP');
hold on;
plot(1:simulationSteps, vdop, 'c.-', 'DisplayName', 'VDOP');
xlabel('Krok symulacji (czas w sekundach)');
ylabel('Wartość DOP');
title('Horizontal and Vertical Dilution of Precision (HDOP, VDOP)');
legend('show', 'Location', 'best');
grid on;
ylim([0, max([10, max(hdop), max(vdop)])]); 

disp('Zakończono symulację i wizualizację.');
function [x, y, z] = latlon2ecef(lat, lon, h)    
    a = 6378137.0; 
    f = 1/298.257223563; 
    e_sq = f * (2 - f); 

    lat_rad = deg2rad(lat);
    lon_rad = deg2rad(lon);
    
    N = a / sqrt(1 - e_sq * sin(lat_rad)^2); 
    
    x = (N + h) * cos(lat_rad) * cos(lon_rad);
    y = (N + h) * cos(lat_rad) * sin(lon_rad);
    z = (N * (1 - e_sq) + h) * sin(lat_rad);
end

function vecef = ned2ecefv(vn, ve, vd, lat, lon)
  
    lat_rad = deg2rad(lat);
    lon_rad = deg2rad(lon);
    
    clat = cos(lat_rad);
    slat = sin(lat_rad);
    clon = cos(lon_rad);
    slon = sin(lon_rad);
    
    R_ne = [-slat*clon, -slat*slon,  clat;
            -slon,       clon,       0;
            -clat*clon, -clat*slon, -slat];
            
    vned = [vn; ve; vd];
    vecef_vec = R_ne' * vned; 
    vecef = vecef_vec';
end