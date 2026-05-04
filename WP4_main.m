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

% Crear tabla con los vuelos eliminados
removed_flights = llegadas_original(flights_to_remove, :);

% Definir tiempo adicional basado en las diapositivas
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



%% --- CALCULAR GDP ORIGINAL EN SILENCI ---
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
    routes_air_gCO2_delay(end+1) = base_gco2_ask + delay_gco2_ask; 
    routes_rail_gCO2(end+1) = (co2_pax * 1000) / dist;
    
    % 5. Càlcul D2D en s/km
    routes_air_skm_nodelay(end+1) = ((flight_time_h + additional_air) * 3600) / dist;
    routes_air_skm_delay(end+1) = ((flight_time_h + additional_air + avg_delay_h) * 3600) / dist;
    routes_rail_skm(end+1) = ((t_rail + additional_rail) * 3600) / dist;
    
    valid_airports{end+1} = char(adep);
    routes_dist(end+1) = dist;
end

% Ordenar per distància per connectar les línies
[sorted_dist, s_idx] = sort(routes_dist);
air_gCO2 = routes_air_gCO2(s_idx); 
air_gCO2_delay = routes_air_gCO2_delay(s_idx); 
rail_gCO2 = routes_rail_gCO2(s_idx);
air_skm_no = routes_air_skm_nodelay(s_idx); 
air_skm_yes = routes_air_skm_delay(s_idx);
rail_skm = routes_rail_skm(s_idx); 
names = valid_airports(s_idx);

%% --- DIBUIXAR EL GRÀFIC COMBINAT---
color_air = [0.000 0.447 0.741];     % Blau (Avió Baseline)
color_air_d = [0.850 0.325 0.098];   % Vermell (Avió amb Retard)
color_rail = [0.466 0.674 0.188];    % Verd (Tren)


max_left_y = 250; 
max_right_y = max([max(air_skm_no), max(air_skm_yes), max(rail_skm)]) * 1.05;


figure('Name', 'Intermodality Comparison', 'Color', 'w', 'Position', [100, 100, 900, 550]);
title('Intermodality Comparison: Flight vs Rail (Baseline & Regulated)', 'FontWeight', 'bold', 'FontSize', 12);
grid on; hold on;

% --- Eix Esquerre (Emissions - Línies Contínues) ---
yyaxis left
p1 = plot(sorted_dist, air_gCO2, '-o', 'Color', color_air, 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
p2 = plot(sorted_dist, air_gCO2_delay, '-s', 'Color', color_air_d, 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
p3 = plot(sorted_dist, rail_gCO2, '-d', 'Color', color_rail, 'LineWidth', 1.5, 'MarkerFaceColor', 'w');


ylabel('gCO_2/ASK (Solid Lines)', 'Color', 'k', 'FontWeight', 'bold');
set(gca, 'ycolor', 'k'); ylim([0 max_left_y]);

% Línies verticals i noms de ciutats
for i = 1:length(sorted_dist)
    xline(sorted_dist(i), ':', 'Color', [0.8 0.8 0.8]);
    text(sorted_dist(i), max_left_y*0.98, names{i}, 'Rotation', 90, 'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
end

% --- Eix Dret (Temps D2D - Línies Discontínues) ---
yyaxis right
p4 = plot(sorted_dist, air_skm_no, '--o', 'Color', color_air, 'LineWidth', 1.5, 'MarkerSize', 6);
p5 = plot(sorted_dist, air_skm_yes, '--s', 'Color', color_air_d, 'LineWidth', 1.5, 'MarkerSize', 6);
p6 = plot(sorted_dist, rail_skm, '--d', 'Color', color_rail, 'LineWidth', 1.5, 'MarkerSize', 6);

ylabel('D2D Time s/km (Dashed Lines)', 'Color', 'k', 'FontWeight', 'bold');
set(gca, 'ycolor', 'k'); ylim([0 max_right_y]); 
xlabel('Distance (km)', 'FontWeight', 'bold');


legend([p1, p4, p2, p5, p3, p6], ...
    {'Air Baseline Emissions', 'Air Baseline Time', ...
     'Air Regulated Emissions', 'Air Regulated Time', ...
     'Rail Emissions', 'Rail Time'}, ...
    'Location', 'northoutside', 'FontSize', 9, 'NumColumns', 3);


%% --- CÀLCUL DE LA NOVA HNoReg (ESCENARI INTERMODAL) ---
[new_HNoReg_val, ~] = calcular_regulacion(horas_vuelos, Hstart, Hend, PAAR, AAR);

new_H = floor(new_HNoReg_val);
new_M = round((new_HNoReg_val - new_H) * 60);

fprintf('--- RESULTATS DE CONGESTIÓ (NOVA HNoReg) ---\n');
fprintf('Antiga HNoReg (Original): %.2fh\n', HNoReg);
fprintf('Nova HNoReg (Amb trens):  %02d:%02d (%.2fh)\n', new_H, new_M, new_HNoReg_val);
fprintf('Temps de congestió estalviat: %.2f hores\n\n', HNoReg - new_HNoReg_val);

%% --- GHP INTERMODALITY ---
fprintf("\n\n------------------------------------\n");
fprintf("--- WP4: GHP WITH INTERMODALITY ---\n");

% 1. Preparar les dades de la taula filtrada 'llegadas'
ARCID_inter     = string(llegadas.ARCID);
ETA_hours_inter = llegadas.ETA * 24;
ETD_hours_inter = llegadas.ETD * 24;
Distances_inter = llegadas.Flight_Distance_km_;
ECAC_inter      = llegadas.ECAC;

% 2. Recalcular els paràmetres del GDP per la demanda reduïda
[new_HNoReg_val, ~] = calcular_regulacion(ETA_hours_inter, Hstart, Hend, PAAR, AAR);
slots_inter = compute_slots(Hstart, Hend, new_HNoReg_val, PAAR, AAR);

% 3. Tornar a classificar els vols amb la nova HNoReg
[~, ~, ~, ~, Exempt_inter, Controlled_inter] = compute_list(ARCID_inter, ETA_hours_inter, ...
    ETD_hours_inter, Distances_inter, ECAC_inter, Hfile, Hstart, new_HNoReg_val, radius);

% 4. Assingar slots GDP
[~, GroundDelay_inter, AirDelay_inter] = assign_slots(slots_inter, Controlled_inter, Exempt_inter, ...
    ETA_hours_inter, ETD_hours_inter, ARCID_inter);

% 5. Preparar els vols per a l'optimització GHP
vuelos_opt_inter = [Controlled_inter; Exempt_inter];
max_air_delay = 45; % minuts
max_ground_delay = 360; % minuts

% --- Task 1: Cost unitari (Minimitzar retard) ---
[x_inter, coste_minimo_inter] = solve_GHP(vuelos_opt_inter, slots_inter, ARCID_inter, ETA_hours_inter, Exempt_inter, max_air_delay, max_ground_delay);

% --- Task 2: Minimitzar emissions CO2 ---
[x_em_inter, coste_emisiones_inter] = solve_ghp_emissions(vuelos_opt_inter, slots_inter, ARCID_inter, ETA_hours_inter, llegadas, Exempt_inter, max_air_delay, max_ground_delay);

% --- Task 3: Minimitzar costos del retard ---
% Utilitzem llegadas_original per si la funció busca informació del model d'avió allà
[x_costs_inter, coste_delay_inter] = solve_GHP_costs(vuelos_opt_inter, slots_inter, llegadas_original, Exempt_inter, max_air_delay, max_ground_delay);

% --- Resultats globals Intermodalitat ---
fprintf('INTERMODAL - Total minimum delay found: %.2f mins\n', coste_minimo_inter);
fprintf('INTERMODAL - Total minimum CO2 cost found: %.2f kg CO2\n', coste_emisiones_inter);
fprintf('INTERMODAL - Minimum delay cost found: %.2f €\n', coste_delay_inter);

% --- Task 4: KPIs detallats ---
compute_kpis_GHP(x_inter, vuelos_opt_inter, slots_inter, ARCID_inter, ETA_hours_inter, llegadas, Exempt_inter, 'Intermodality Task1 - Unitary', GroundDelay_inter, AirDelay_inter);
compute_kpis_GHP(x_em_inter, vuelos_opt_inter, slots_inter, ARCID_inter, ETA_hours_inter, llegadas, Exempt_inter, 'Intermodality Task2 - Emissions', GroundDelay_inter, AirDelay_inter);

%% --- Task 5: Comparació GDP vs GHP (Escenari Intermodal) ---
fprintf("\n========== INTERMODALITY: GDP vs GHP ==========\n");

% Retards i emissions GDP intermodal
ground_delays_GDP_inter = cell2mat(GroundDelay_inter(:, 2));
total_CO2_ground_GDP_inter = sum(ground_delays_GDP_inter) * 2.5;
[~, total_CO2_air_GDP_inter] = compute_air_emissions(AirDelay_inter, llegadas, ARCID_inter);
total_CO2_GDP_inter = total_CO2_air_GDP_inter + total_CO2_ground_GDP_inter;
total_delay_GDP_inter = sum(ground_delays_GDP_inter) + sum(cell2mat(AirDelay_inter(:, 2)));

% Resultats GHP intermodal
total_delay_GHP_inter = coste_minimo_inter;
total_CO2_GHP_inter   = coste_emisiones_inter;

% Imprimir taula
fprintf('%-20s | %-15s | %-15s\n', 'Metric', 'GDP (Intermodal)', 'GHP (Intermodal)');
fprintf('------------------------------------------------------------\n');
fprintf('%-20s | %-15.2f | %-15.2f\n', 'Total Delay (min)',  total_delay_GDP_inter, total_delay_GHP_inter);
fprintf('%-20s | %-15.2f | %-15.2f\n', 'CO2 Emissions (kg)', total_CO2_GDP_inter,   total_CO2_GHP_inter);
fprintf('%-20s | %-15.2f | %-15.2f\n', 'CO2 saved vs GDP',   0, total_CO2_GDP_inter - total_CO2_GHP_inter);
fprintf('====================================================\n');