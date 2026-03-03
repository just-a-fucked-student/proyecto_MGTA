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
Hfile = 6;     % hora publicación regulación (aún no usado en WP1)
Hstart = 8;    % inicio reducción
Hend = 14;     % fin reducción

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

exportgraphics(gcf, 'Histograma_Arribades.png', 'Resolution', 300);

%% Calcular regulación (WP1)
[HNoReg, delay] = calcular_regulacion(llegadas.ETA, Hstart, Hend, PAAR, AAR);

fprintf('HNoReg = %.2f UTC hours\n', HNoReg);
fprintf('Total minimum delay = %.2f (minutes * aircraft)\n', delay);

%% Crear slots (WP1)
slots = compute_slots(Hstart, Hend, HNoReg, PAAR, AAR);

% Mostrar primeras filas para comprobar
disp('Primeros 10 slots:')
disp(slots(1:10,:))

% Guardar slots por si se necesitan después
writematrix(slots, 'slots_WP1.csv');