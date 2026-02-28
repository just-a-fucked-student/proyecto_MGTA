clearvars
clc
close all

%Cargar Datos desde el xlsx

aeropuerto = "LEBL_10AUG2025.xlsx";
%Guarda todos los datos (lee la primera hoja)
data = readtable(aeropuerto);
%Guarda solo la segunda hoja del excel(llegadas)
llegadas = readtable(aeropuerto,'Sheet','LLEGADAS');

% disp("Primeras 8 filas:")   //Test
% disp(head(data,8))




