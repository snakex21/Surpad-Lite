dx = x2 - x1;
dy = y2 - y1;


azymut_rad = atan2(dx, dy);  


azymut_deg = rad2deg(azymut_rad);

if azymut_deg < 0
    azymut_deg = azymut_deg + 360;
end
