clearvars
clc
close all

%% Cargar datos desde xlsx
aeropuerto = "LEBL_10AUG2025.xlsx";
llegadas_original = readtable(aeropuerto, 'Sheet', 'LLEGADAS');

%% Parametros
AAR    = 40;
PAAR   = 20;
Hfile  = 4;
Hstart = 6;
Hend   = 13;
radius = 1200;

%% Intermodality (WP4)
airports_to_remove = ["LEMD", "LEAL", "LELN", "LEGE", "LEZL", "LEMG", ...
                      "LFML", "LFLL", "LESO"];

% Extraer las horas de llegada originales
ETA_original_hours = llegadas_original.ETA * 24;
[HNoReg, ~] = calcular_regulacion(ETA_original_hours, Hstart, Hend, PAAR, AAR);
close;

fprintf('La regulación original termina a las: %.2fh\n', HNoReg);

% Condición A: El vuelo viene de una ciudad a < 6h en tren
is_short_train = ismember(string(llegadas_original.ADEP), airports_to_remove);

% Condición B: El vuelo aterriza DENTRO del intervalo de regulación
is_in_regulation = (ETA_original_hours >= Hstart) & (ETA_original_hours < HNoReg);

% Vuelos a sustituir: cumplen ambas condiciones
flights_to_remove = is_short_train & is_in_regulation;

% Crear la nueva tabla eliminando los vuelos
llegadas = llegadas_original(~flights_to_remove, :);

fprintf('--- INTERMODALITY ---\n');
fprintf('Original flights (24h): %d\n', height(llegadas_original));
fprintf('Flights removed (Train < 6h AND within regulation): %d\n', sum(flights_to_remove));
fprintf('Flights remaining for the GDP: %d\n\n', height(llegadas));

% Extraer ETA de la tabla FILTRADA
horas_vuelos = llegadas.ETA * 24;

% Create a table with ONLY the substituted flights
removed_flights = llegadas_original(flights_to_remove, :);

% Define D2D overheads in hours based on the slides
additional_air = 150 / 60;   
additional_rail = 60 / 60;   

total_rail_CO2 = 0;
total_air_D2D_hours = 0;
total_rail_D2D_hours = 0;

fprintf('--- SUBSTITUTED FLIGHTS ANALYSIS (RAIL vs AIR) ---\n');
fprintf('%-10s | %-15s | %-10s | %-10s | %-10s\n', 'Flight', 'City (ICAO)', 'Air D2D', 'Rail D2D', 'Rail CO2(kg)');
fprintf('----------------------------------------------------------------------\n');

for i = 1:height(removed_flights)
    adep = string(removed_flights.ADEP(i));
    flight_id = string(removed_flights.ARCID(i));
    seats = removed_flights.Seats(i);
    
    if isnan(seats) || seats == 0; seats = 150; end % Default seats
    
    % Get Air flight time (ETA - ETD)
    etd_f = removed_flights.ETD(i) * 24;
    eta_f = removed_flights.ETA(i) * 24;
    if etd_f > eta_f; etd_f = etd_f - 24; end
    air_flight_time = eta_f - etd_f;
    
    % Values estimated from EcoPassenger / Chronotrains to BCN
    switch adep
        case "LEMD" % Madrid
            train_time = 2.5; train_co2_pax = 18.9;
        case "LEAL" % Alicante
            train_time = 5.0; train_co2_pax = 15.9;
        case "LEZL" % Sevilla
            train_time = 5.5; train_co2_pax = 32.3;
        case "LEMG" % Malaga
            train_time = 6.0; train_co2_pax = 33.4;
        case "LEGE" % Girona
            train_time = 1.0; train_co2_pax = 2.9;
        case "LELN" % Leon
            train_time = 6.0; train_co2_pax = 28.9;
        case "LFML" % Marseille
            train_time = 5.0; train_co2_pax = 7.2;
        case "LFLL" % Lyon
            train_time = 5.5; train_co2_pax = 8.1;
        case "LESO" % San Sebastian
            train_time = 6.0; train_co2_pax = 19.1;
        otherwise
            train_time = 4.0; train_co2_pax = 20; % Fallback
    end
    
    % Calculate D2D
    air_D2D = air_flight_time + additional_air;
    rail_D2D = train_time + additional_rail;
    
    % Calculate Rail CO2 for this specific journey (pax * CO2/pax)
    flight_rail_CO2 = seats * train_co2_pax;
    
    % Add to totals
    total_air_D2D_hours = total_air_D2D_hours + air_D2D;
    total_rail_D2D_hours = total_rail_D2D_hours + rail_D2D;
    total_rail_CO2 = total_rail_CO2 + flight_rail_CO2;
    
    % Print row
    fprintf('%-10s | %-15s | %-8.2fh | %-8.2fh | %-8.2f\n', flight_id, adep, air_D2D, rail_D2D, flight_rail_CO2);
end

fprintf('----------------------------------------------------------------------\n');
fprintf('TOTAL Rail Carbon Footprint for substituted flights: %.2f kg CO2\n', total_rail_CO2);
fprintf('Average Air D2D time:  %.2f hours\n', total_air_D2D_hours / height(removed_flights));
fprintf('Average Rail D2D time: %.2f hours\n\n', total_rail_D2D_hours / height(removed_flights));



%% --- CALCULAR GDP ORIGINAL EN SILENCI (Per al Gràfic 2) ---
% Necessitem el GroundDelay del WP2 per a l'Escenari 2
slots_orig = compute_slots(Hstart, Hend, HNoReg, PAAR, AAR);
[~, ~, ~, ~, Exempt_orig, Controlled_orig] = compute_list(llegadas_original.ARCID, ETA_original_hours, ...
    (llegadas_original.ETD*24), llegadas_original.Flight_Distance_km_, llegadas_original.ECAC, ...
    Hfile, Hstart, HNoReg, radius);
[~, GroundDelay_orig, ~] = assign_slots(slots_orig, Controlled_orig, Exempt_orig, ETA_original_hours, ...
    (llegadas_original.ETD*24), llegadas_original.ARCID);

%% --- PREPARACIÓ DE DADES PER ALS GRÀFICS ---
routes_dist = []; routes_air_gCO2 = []; routes_air_gCO2_delay = []; routes_rail_gCO2 = [];
routes_air_skm_nodelay = []; routes_air_skm_delay = []; routes_rail_skm = [];
valid_airports = {};

for i = 1:length(airports_to_remove)
    adep = airports_to_remove(i);
    idx = find(string(llegadas_original.ADEP) == adep);
    if isempty(idx); continue; end
    
    % 1. Distància
    dist = mean(llegadas_original.Flight_Distance_km_(idx));
    
    % 2. Dades del tren
    switch adep
        case "LEMD", t_rail = 2.5; co2_pax = 18.9;
        case "LEAL", t_rail = 5.0; co2_pax = 15.9;
        case "LEZL", t_rail = 5.5; co2_pax = 32.3;
        case "LEMG", t_rail = 6.0; co2_pax = 33.4;
        case "LEGE", t_rail = 1.0; co2_pax = 2.9;
        case "LELN", t_rail = 6.0; co2_pax = 28.9;
        case "LFML", t_rail = 5.0; co2_pax = 7.2;
        case "LFLL", t_rail = 5.5; co2_pax = 8.1;
        case "LESO", t_rail = 6.0; co2_pax = 19.1;
        otherwise,   t_rail = 4.0; co2_pax = 20.0;
    end
    
    % 3. Càlcul de Temps de vol i Retard Mitjà de la Ruta
    flight_time_h = mean(llegadas_original.ETA(idx)*24 - llegadas_original.ETD(idx)*24);
    if flight_time_h < 0; flight_time_h = flight_time_h + 24; end
    
    route_delays = zeros(1, length(idx));
    vols_ruta = string(llegadas_original.ARCID(idx));
    for v = 1:length(vols_ruta)
        idx_gd = find(string(GroundDelay_orig(:,1)) == vols_ruta(v));
        if ~isempty(idx_gd)
            route_delays(v) = GroundDelay_orig{idx_gd, 2};
        end
    end
    avg_delay_mins = mean(route_delays);
    avg_delay_h = avg_delay_mins / 60;
    
    % 4. Càlculs emissions (gCO2/ASK)
    try
        fuel_ask_g = emissions_fuel_model.compute_fuel_ask(dist, 150);
    catch
        fuel_ask_g = 16.0;
    end
    
    base_gco2_ask = fuel_ask_g * 3.16;
    
    % Emissions extra per Ground Delay: ~2.5 kg CO2/min passats a grams per ASK
    delay_gco2_ask = (avg_delay_mins * 2.5 * 1000) / (150 * dist);
    
    routes_air_gCO2(end+1) = base_gco2_ask;
    routes_air_gCO2_delay(end+1) = base_gco2_ask + delay_gco2_ask; % <-- DADA CORREGIDA PER A L'ESCENARI 2
    routes_rail_gCO2(end+1) = (co2_pax * 1000) / dist;
    
    % 5. Càlcul D2D en s/km
    routes_air_skm_nodelay(end+1) = ((flight_time_h + additional_air) * 3600) / dist;
    routes_air_skm_delay(end+1) = ((flight_time_h + additional_air + avg_delay_h) * 3600) / dist;
    routes_rail_skm(end+1) = ((t_rail + additional_rail) * 3600) / dist;
    
    valid_airports{end+1} = char(adep);
    routes_dist(end+1) = dist;
end

% Ordenar per distància per connectar les línies de forma coherent
[sorted_dist, s_idx] = sort(routes_dist);
air_gCO2 = routes_air_gCO2(s_idx); 
air_gCO2_delay = routes_air_gCO2_delay(s_idx); % <- Emissions amb retard
rail_gCO2 = routes_rail_gCO2(s_idx);
air_skm_no = routes_air_skm_nodelay(s_idx); 
air_skm_yes = routes_air_skm_delay(s_idx);
rail_skm = routes_rail_skm(s_idx); 
names = valid_airports(s_idx);

%% --- DIBUIXAR ELS GRÀFICS ---
color_emis = [0.000 0.447 0.741]; % Blau
color_time = [0.850 0.325 0.098]; % Taronja

% Fixem l'eix esquerre a 250 perquè les línies tinguin la forma original
max_left_y = 250; 


max_right_y = max([max(air_skm_no), max(air_skm_yes), max(rail_skm)]) * 1.05;

% --- GRÀFIC 1: SENSE RETARD (Baseline) ---
figure('Name', 'No Delay', 'Color', 'w', 'Position', [100, 100, 700, 500]);
title('No Delay', 'FontWeight', 'bold', 'FontSize', 12);
grid on; hold on;

% Eix Esquerre (Emissions)
yyaxis left
p1 = plot(sorted_dist, air_gCO2, '-o', 'Color', color_emis, 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
p2 = plot(sorted_dist, rail_gCO2, '--o', 'Color', color_emis, 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
ylabel('gCO_2/ASK', 'Color', color_emis, 'FontWeight', 'bold');
set(gca, 'ycolor', color_emis); ylim([0 max_left_y]);

for i = 1:length(sorted_dist)
    xline(sorted_dist(i), ':', 'Color', [0.8 0.8 0.8]);
    text(sorted_dist(i), max_left_y*0.98, names{i}, 'Rotation', 90, 'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
end

% Eix Dret (Temps D2D)
yyaxis right
p3 = plot(sorted_dist, air_skm_no, '-x', 'Color', color_time, 'LineWidth', 1.5);
p4 = plot(sorted_dist, rail_skm, '--x', 'Color', color_time, 'LineWidth', 1.5);
ylabel('D2D Time (s/km)', 'Color', color_time, 'FontWeight', 'bold');
set(gca, 'ycolor', color_time); ylim([0 max_right_y]);
xlabel('Distance (km)', 'FontWeight', 'bold');

legend([p1, p2, p3, p4], {'Flight Emissions', 'Rail Emissions', 'Flight Time', 'Rail Time'}, 'Location', 'northeast');


% --- GRÀFIC 2: AMB RETARD (Regulated) ---
figure('Name', 'With GDP Delay (Regulated)', 'Color', 'w', 'Position', [820, 100, 700, 500]);
title('With GDP Delay (Regulated)', 'FontWeight', 'bold', 'FontSize', 12);
grid on; hold on;

% Eix Esquerre (Emissions AMB RETARD)
yyaxis left
p5 = plot(sorted_dist, air_gCO2_delay, '-o', 'Color', color_emis, 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
p6 = plot(sorted_dist, rail_gCO2, '--o', 'Color', color_emis, 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
ylabel('gCO_2/ASK', 'Color', color_emis, 'FontWeight', 'bold');
set(gca, 'ycolor', color_emis); ylim([0 max_left_y]);

for i = 1:length(sorted_dist)
    xline(sorted_dist(i), ':', 'Color', [0.8 0.8 0.8]);
    text(sorted_dist(i), max_left_y*0.98, names{i}, 'Rotation', 90, 'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
end

% Eix Dret (Temps D2D AMB RETARD)
yyaxis right
p7 = plot(sorted_dist, air_skm_yes, '-x', 'Color', color_time, 'LineWidth', 1.5);
p8 = plot(sorted_dist, rail_skm, '--x', 'Color', color_time, 'LineWidth', 1.5);
ylabel('D2D Time (s/km)', 'Color', color_time, 'FontWeight', 'bold');
set(gca, 'ycolor', color_time); ylim([0 max_right_y]); 
xlabel('Distance (km)', 'FontWeight', 'bold');

legend([p5, p6, p7, p8], {'Flight Emissions', 'Rail Emissions', 'Flight Time', 'Rail Time'}, 'Location', 'northeast');