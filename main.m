clearvars
clc
close all

%% Cargar Datos desde el xlsx
aeropuerto = "LEBL_10AUG2025.xlsx";

% Guarda todos los datos (lee la primera hoja)
data = readtable(aeropuerto);

% Guarda solo la segunda hoja del excel (llegadas)
llegadas = readtable(aeropuerto,'Sheet','LLEGADAS');

% Pasar ETA a horas (está en fracción de día)
horas_vuelos = llegadas.ETA * 24;  

%% Parámetros
AAR = 40;      % capacidad nominal (arrivals/hour)
PAAR = 20;     % capacidad reducida
Hfile = 4;     % hora publicación regulación
Hstart = 6;    % inicio reducción
Hend = 13;     % fin reducción
radius = 1500; 

%% Gráfico demanda-capacidad
figure;
histogram(horas_vuelos, 0:24, 'FaceColor', [0.2 0.2 0.6]); 
hold on; 

plot([0, Hstart], [AAR, AAR], 'g', 'LineWidth', 2);
plot([Hstart, Hend], [PAAR, PAAR], 'r', 'LineWidth', 2);
plot([Hend, 24], [AAR, AAR], 'g', 'LineWidth', 2);

title('Histogram of arrivals on non-regulated traffic');
xlabel('Time in UTC (hours)');
ylabel('Arrivals (number of aircraft)');
xlim([0, 24]);          
ylim([0, AAR + 10]);
grid on;

hold off;



%% Calcular regulación (WP1)
[HNoReg, delay] = calcular_regulacion(llegadas.ETA, Hstart, Hend, PAAR, AAR);

%% Crear slots (WP1)
slots = compute_slots(Hstart, Hend, HNoReg, PAAR, AAR);

% Mostrar primeras filas para comprobar
disp('Slots 200 a 202')
disp(slots(200:202,:))

% Guardar slots por si se necesitan después
writematrix(slots, 'slots_WP1.csv');


%% GDP
ARCID = llegadas.ARCID;
ETA_hours = llegadas.ETA * 24; 
ETD_hours = llegadas.ETD * 24; 
Distances = llegadas.Flight_Distance_km_; 
Column_ECAC = llegadas.ECAC;
[NotAffected, ExemptRadius, ExemptInternational, ExemptFlying, Exempt, Controlled] = compute_list(ARCID, ETA_hours, ETD_hours, Distances, Column_ECAC, Hfile, Hstart, HNoReg, radius);
fprintf('Total flights in Excel: %d\n', length(ETA_hours));
fprintf('Flights NOT affected (because schedule): %d\n', length(NotAffected));
fprintf('Flights EXEMPTS (Total): %d\n', length(Exempt));
fprintf('Exempts beacuse radius (>%d KM): %d\n', radius, length(ExemptRadius));
fprintf('Exempts because already flying: %d\n', length(ExemptFlying));
fprintf('Exempts because being NO ECAC: %d\n', length(ExemptInternational));
fprintf('Flights CONTROLLED (GDP): %d\n', length(Controlled));

%Asign the slots and dealys
[final_slots, GroundDelay, AirDealy] = assign_slots(slots, Controlled, Exempt, ETA_hours, ETD_hours, ARCID);
disp('(Min | ID)');
disp(final_slots(200:205, :));
disp('Ground delay');
disp(GroundDelay(1:5, :));
