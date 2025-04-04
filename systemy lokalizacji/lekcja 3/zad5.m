function zad5
    sc = satelliteScenario;

    sat = satellite(sc, "threeSatelliteConstellation.tle");

    show(sat);
    groundTrack(sat, "LeadTime", 1200);

    name = [
        "Goldstone Deep Space Communications Complex", ...
        "GPS Bahrain NGA BHR400BHR", ...
        "Fikcyjna stacja - Budynek C Tarnów"
    ];

    lat = [35.3479, 26.07, 50.01549];        
    lon = [-116.8889, 50.55, 20.9895];   

    gs = groundStation(sc, "Name", name, "Latitude", lat, "Longitude", lon);

end
