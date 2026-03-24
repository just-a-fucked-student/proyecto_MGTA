clearvars
clc
close all

%% Cargar Datos desde el xlsx
aeropuerto = "LEBL_10AUG2025.xlsx";
llegadas = readtable(aeropuerto, 'Sheet', 'LLEGADAS');
horas_vuelos = llegadas.ETA * 24;

%% Parametros
AAR    = 40;
PAAR   = 20;
Hfile  = 4;
Hstart = 6;
Hend   = 13;
radius = 1200;

%% Grafico demanda-capacidad
figure;
histogram(horas_vuelos, 0:24, 'FaceColor', [0.2 0.2 0.6]);
hold on;
plot([0, Hstart], [AAR, AAR],   'g', 'LineWidth', 2);
plot([Hstart, Hend], [PAAR, PAAR], 'r', 'LineWidth', 2);
plot([Hend, 24],   [AAR, AAR],  'g', 'LineWidth', 2);
title('Histogram of arrivals on non-regulated traffic');
xlabel('Time in UTC (hours)');
ylabel('Arrivals (number of aircraft)');
xlim([0, 24]); ylim([0, AAR + 10]);
grid on; hold off;

%% Calcular regulacion (WP1)
[HNoReg, delay] = calcular_regulacion(llegadas.ETA, Hstart, Hend, PAAR, AAR);

%% Crear slots (WP1)
slots = compute_slots(Hstart, Hend, HNoReg, PAAR, AAR);
disp('Slots 200 a 202'); disp(slots(200:202,:))
writematrix(slots, 'slots_WP1.csv');

%% GDP
ARCID       = llegadas.ARCID;
ETA_hours   = llegadas.ETA * 24;
ETD_hours   = llegadas.ETD * 24;
Distances   = llegadas.Flight_Distance_km_;
Column_ECAC = llegadas.ECAC;

[NotAffected, ExemptRadius, ExemptInternational, ExemptFlying, Exempt, Controlled] = ...
    compute_list(ARCID, ETA_hours, ETD_hours, Distances, Column_ECAC, Hfile, Hstart, HNoReg, radius);

fprintf('Total flights in Excel: %d\n',              length(ETA_hours));
fprintf('Flights NOT affected (because schedule): %d\n', length(NotAffected));
fprintf('Flights EXEMPTS (Total): %d\n',             length(Exempt));
fprintf('Exempts because radius (>%d KM): %d\n',    radius, length(ExemptRadius));
fprintf('Exempts because already flying: %d\n',     length(ExemptFlying));
fprintf('Exempts because being NO ECAC: %d\n',      length(ExemptInternational));
fprintf('Flights CONTROLLED (GDP): %d\n',            length(Controlled));

[final_slots, GroundDelay, AirDelay] = assign_slots(slots, Controlled, Exempt, ETA_hours, ETD_hours, ARCID);
disp('(Min | ID)'); disp(final_slots(200:205, :));
disp('Ground delay'); disp(GroundDelay(1:5, :));

%% CTA
CTA_hours = compute_CTA(ARCID, ETA_hours, GroundDelay, AirDelay);

%% Grafico horas reguladas
figure;
histogram(CTA_hours, 0:24, 'FaceColor', [0.2 0.2 0.6]);
hold on;
plot([0, Hstart],    [AAR, AAR],   'g', 'LineWidth', 2);
plot([Hstart, Hend], [PAAR, PAAR], 'r', 'LineWidth', 2);
plot([Hend, 24],     [AAR, AAR],   'g', 'LineWidth', 2);
title('Histogram of arrivals on regulated traffic');
xlabel('Time in UTC (hours)');
ylabel('Arrivals (number of aircraft)');
xlim([0, 24]); ylim([0, AAR + 10]);
grid on; hold off;

%% Unrecoverable Delay
[UnrecoverableDelay, total_unrecoverable] = ...
    compute_unrecoverable_delay(GroundDelay, ETD_hours, ETA_hours, ARCID, Hstart);

fprintf('\n--- UNRECOVERABLE DELAY ---\n');
fprintf('Total Unrecoverable Delay: %.2f min\n', total_unrecoverable);
disp('Show the first 5 flights with unrecoverable delay:');
disp(UnrecoverableDelay(1:5, :));

%% Emissions per Air Delay (WP2)
[AirEmissions, total_CO2_air_delay] = compute_air_emissions(AirDelay, llegadas, ARCID);

fprintf('\n--- EMISSIONS CO2 (AIR DELAY) ---\n');
fprintf('Total CO2 of Air Delay: %.2f kg\n', total_CO2_air_delay);
disp('Show the first 5 flights (kg CO2 | ID):');
disp(AirEmissions(1:5, :));

%% Cancellation and effect on main airlines with ground delay
chosenAirline  = 'VLG';
delayThreshold = 180;

% Sacar codigo de aerolinea de los vuelos con ground delay
numGroundFlights = size(GroundDelay, 1);
airlineCodeGround = cell(numGroundFlights, 1);
for k = 1:numGroundFlights
    airlineCodeGround{k} = get_airline_code(char(GroundDelay{k, 1}));
end

% Top 4 aerolineas con mas vuelos en GroundDelay
[uniqueAirlines, ~, idx] = unique(airlineCodeGround);
counts = accumarray(idx, 1);
[~, order] = sort(counts, 'descend');
numTopAirlines = min(4, length(uniqueAirlines));
topAirlines = uniqueAirlines(order(1:numTopAirlines));

% Delay medio antes
meanDelayBefore = zeros(numTopAirlines, 1);
for a = 1:numTopAirlines
    currentAirline = topAirlines{a};
    delaysAirline = [];
    for k = 1:size(GroundDelay, 1)
        flightID = char(GroundDelay{k, 1});
        if strcmp(get_airline_code(flightID), currentAirline)
            delaysAirline(end+1) = GroundDelay{k, 2};
        end
    end
    if ~isempty(delaysAirline)
        meanDelayBefore(a) = mean(delaysAirline);
    end
end

% Aplicamos cancelacion y compression
[slots2, GroundDelay2, cancelledFlights, KPI_cancel] = ...
    cancel_subs(final_slots, ETA_hours, ARCID, GroundDelay, delayThreshold, chosenAirline);

% Delay medio despues
meanDelayAfter = zeros(numTopAirlines, 1);
for a = 1:numTopAirlines
    currentAirline = topAirlines{a};
    delaysAirline = [];
    for k = 1:size(GroundDelay2, 1)
        flightID = char(GroundDelay2{k, 1});
        if strcmp(get_airline_code(flightID), currentAirline)
            delaysAirline(end+1) = GroundDelay2{k, 2};
        end
    end
    if ~isempty(delaysAirline)
        meanDelayAfter(a) = mean(delaysAirline);
    end
end

%% Plot top aerolineas por delay medio
numGD = size(GroundDelay, 1);
airlineCodes = cell(numGD, 1);
delayValues  = zeros(numGD, 1);
for k = 1:numGD
    airlineCodes{k} = get_airline_code(char(GroundDelay{k, 1}));
    delayValues(k)  = GroundDelay{k, 2};
end

[uniqueAL, ~, idxAL] = unique(airlineCodes);
totalDelay = accumarray(idxAL, delayValues);
numFlights = accumarray(idxAL, ones(numGD, 1));
meanDelay  = totalDelay ./ numFlights;

[~, ordTotal] = sort(totalDelay, 'descend');
top    = min(10, length(uniqueAL));
topIdx = ordTotal(1:top);

figure;
bar(meanDelay(topIdx), 'FaceColor', [0.8 0.3 0.2]);
set(gca, 'XTick', 1:top, 'XTickLabel', uniqueAL(topIdx));
xlabel('Airline');
ylabel('Mean Ground Delay per flight (min)');
title('Top airlines by mean ground delay');
grid on;

%% Plot efecto de cancelar
figure;
bar([meanDelayBefore meanDelayAfter]);
grid on;
xlabel('Airline');
ylabel('Mean ground delay (min)');
title(['Effect of cancelling flights from ', chosenAirline]);
legend('Before cancellation', 'After cancellation');
set(gca, 'XTick', 1:numTopAirlines);
set(gca, 'XTickLabel', topAirlines);

% Resultados
disp('Main airlines in GroundDelay:'), disp(topAirlines)
disp('Mean delay before:'),            disp(meanDelayBefore)
disp('Mean delay after:'),             disp(meanDelayAfter)
disp('Cancelled flights:'),            disp(cancelledFlights)
disp('KPIs:'),                         disp(KPI_cancel)

%% KPIs globales
num_total_flights = length(ARCID);
compute_kpis(AirDelay, GroundDelay, num_total_flights, total_CO2_air_delay);

%% Compute the heatmaps and the varying parameters. 
compute_heatmaps(ARCID, ETA_hours, ETD_hours, Distances, Column_ECAC, Hstart, HNoReg, slots, llegadas);
