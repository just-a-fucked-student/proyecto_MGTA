clearvars
clc
close all

%Cargar Datos desde el xlsx

aeropuerto = "LEBL_10AUG2025.xlsx";
%Guarda todos los datos (lee la primera hoja)
data = readtable(aeropuerto);
%Guarda solo la segunda hoja del excel(llegadas)
llegadas = readtable(aeropuerto,'Sheet','LLEGADAS');
horas_vuelos = llegadas.ETA *24;  
% disp("Primeras 8 filas:")   //Test
% disp(head(data,8))

AAR = 40;
PAAR = 20;
Hfile = 6;
Hstart = 8;
Hend = 14;

%Gráfico demanda-capacidad
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

hold off;
exportgraphics(gcf, 'Histograma_Arribades.png', 'Resolution', 300);