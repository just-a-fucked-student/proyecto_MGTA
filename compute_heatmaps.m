function compute_heatmaps(ARCID, ETA_hours, ETD_hours, Distances, Column_ECAC, Hstart, HNoReg, slots, llegadas)


    %Define the range of the variables
    radios_test = 0:250:3000; % De 0 a 3000 km en saltos de 250
    hfiles_test = 0:1:Hstart; % De 0h hasta Hstart (6h) en saltos de 1h

    HM_AirDelay = zeros(length(hfiles_test), length(radios_test));
    HM_CO2 = zeros(length(hfiles_test), length(radios_test));
    HM_Unrecoverable = zeros(length(hfiles_test), length(radios_test));