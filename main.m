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