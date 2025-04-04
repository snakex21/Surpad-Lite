function zad6

    startTime = datetime(2025, 6, 2, 8, 23, 0);
    stopTime  = startTime + hours(5);
    sampleTime = 60;  
    sc = satelliteScenario(startTime, stopTime, sampleTime);

    satTLE = satellite(sc, "threeSatelliteConstellation.tle");
    show(satTLE);
    groundTrack(satTLE, "LeadTime", 1200);

    a2     = 30000e3;  
    e2     = 0.01;
    i2     = 55;   
    RAAN2  = 0;      
    omega2 = 0;        
    theta2 = 0;         
    sat2   = satellite(sc, a2, e2, i2, RAAN2, omega2, theta2);
    show(sat2);
    groundTrack(sat2, "LeadTime", 1200);

    a3     = 22000e3;  
    e3     = 0.02;
    i3     = 63;
    RAAN3  = 90;
    omega3 = 0;
    theta3 = 0;
    sat3   = satellite(sc, a3, e3, i3, RAAN3, omega3, theta3);
    show(sat3);
    groundTrack(sat3, "LeadTime", 1200);

    a4     = 26600e3;
    e4     = 0.01;
    i4     = 45;
    RAAN4  = 180;
    omega4 = 0;
    theta4 = 0;
    sat4   = satellite(sc, a4, e4, i4, RAAN4, omega4, theta4);
    show(sat4);
    groundTrack(sat4, "LeadTime", 1200);

    a5     = 42164e3;
    e5     = 0;
    i5     = 0;
    RAAN5  = 0;
    omega5 = 0;
    theta5 = 0;
    sat5   = satellite(sc, a5, e5, i5, RAAN5, omega5, theta5);
    show(sat5);
    groundTrack(sat5, "LeadTime", 1200);

    play(sc);
end
