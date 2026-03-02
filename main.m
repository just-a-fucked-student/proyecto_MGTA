%% MAIN.M (WP1) - LEBL 10AUG2025
clearvars
clc
close all

%% 1) Cargar datos desde el Excel
aeropuerto = "LEBL_10AUG2025.xlsx";

% Leer hoja de llegadas
llegadas = readtable(aeropuerto, 'Sheet', 'LLEGADAS');

%% 2) Preparar horas de llegada para histograma
% ETA está en fracción de día 
horas_vuelos = mod(llegadas.ETA * 24, 24);  

%% 3) Parámetros de capacidad y regulación
AAR  = 40;   % capacidad nominal (arrivals/hour)
PAAR = 20;   % capacidad reducida (arrivals/hour)

% Periodo reducido 1: 08:00 - 14:00
Hstart1 = 8;
Hend1   = 14;

% Periodo reducido 2: 16:00 - 20:00
Hstart2 = 16;
Hend2   = 20;

%% 4) Gráfico: histograma de demanda + líneas de capacidad (2 periodos)
figure;

% Histograma de llegadas por hora
histogram(horas_vuelos, 0:24, 'FaceColor', [0.2 0.2 0.6]);
hold on;

% Líneas de capacidad (AAR verde, PAAR rojo) en 2 tramos reducidos
plot([0, Hstart1],   [AAR, AAR],   'g', 'LineWidth', 2);   % AAR
plot([Hstart1, Hend1],[PAAR, PAAR],'r', 'LineWidth', 2);   % PAAR
plot([Hend1, Hstart2],[AAR, AAR],  'g', 'LineWidth', 2);   % AAR
plot([Hstart2, Hend2],[PAAR, PAAR],'r', 'LineWidth', 2);   % PAAR
plot([Hend2, 24],    [AAR, AAR],   'g', 'LineWidth', 2);   % AAR

title('Histogram of arrivals and capacity (two reduced periods)');
xlabel('Time in UTC (hours)');
ylabel('Arrivals (number of aircraft)');
xlim([0, 24]);
ylim([0, AAR + 10]);
grid on;

hold off;

exportgraphics(gcf, 'Histograma_Arribades_2periodos.png', 'Resolution', 300);

%% 5) WP1 - Calcular HNoReg y delay mínimo total (2 ventanas)
% Llamada a la función común (debe existir como calcular_regulacion.m)
[HNoReg, delay] = calcular_regulacion(llegadas.ETA, ...
    Hstart1, Hend1, Hstart2, Hend2, PAAR, AAR);

% Mostrar resultados
fprintf('HNoReg = %.2f UTC hours\n', HNoReg);
fprintf('Total minimum delay = %.2f (minutes * aircraft)\n', delay);

slots = compute_slots(Hstart1, Hend1, Hstart2, Hend2, HNoReg, PAAR, AAR);

% Ver primeras filas
disp(slots(1:10,:))

writematrix(slots, 'slots_WP1.csv');