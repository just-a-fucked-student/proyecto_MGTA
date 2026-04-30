% Comprobar si las variables necesarias ya están cargadas en el workspace
if ~exist('Controlled', 'var') || ~exist('slots', 'var')
    fprintf('Variables not found in workspace. Running main.m...\n');
    main;
else
    % Diálogo gráfico para preguntar si se quiere recargar
    answer = questdlg('Variables already loaded. Reload WP1/WP2?', ...
                      'Reload Workspace', ...
                      'Yes (run main)', 'No (continue)', 'No (continue)');
    if strcmp(answer, 'Yes (run main)')
        main;
    else
        fprintf('Using existing workspace variables.\n');
    end
end

clc
fprintf("\n\n------------------------------------\n")
fprintf("---WP3---\n")

% Juntamos vuelos controlados y exentos: todos participan en el GHP
vuelos_opt = [Controlled; Exempt];

% Máximo air delay permitido para vuelos exentos
max_air_delay = 45; % minutos

% Task 1: coste unitario (rf=1 para todos) - validación con el GDP
[x, coste_minimo] = solve_GHP(vuelos_opt, slots, ARCID, ETA_hours, Exempt, max_air_delay);

% Task 2: minimizar emisiones CO2 del retardo
[x_em, coste_emisiones] = solve_ghp_emissions(vuelos_opt, slots, ARCID, ETA_hours, llegadas, Exempt, max_air_delay);

%Task 3: minimizar costes del delay
Excel = readtable('LEBL_10AUG2025.xlsx');
[x_costs, coste_delay] = solve_GHP_costs(vuelos_opt, slots, Excel , Exempt, max_air_delay);

% Resultados globales
fprintf('The total minimum delay found is: %.2f mins\n', coste_minimo);
fprintf('The total minimum CO2 cost found is: %.2f kg CO2\n', coste_emisiones);
fprintf('Optimal cost found: %.2f €\n', coste_delay);

% Task 4: KPIs detallados
compute_kpis_GHP(x,    vuelos_opt, slots, ARCID, ETA_hours, llegadas, Exempt, 'Task1 - Unitary Cost', GroundDelay, AirDelay);
compute_kpis_GHP(x_em, vuelos_opt, slots, ARCID, ETA_hours, llegadas, Exempt, 'Task2 - Emissions',    GroundDelay, AirDelay);

%% Task 5: Comparación GDP vs GHP
fprintf("\n========== TASK 5: GDP vs GHP (same rf) ==========\n");

% Calcular los retardos en tierra del GDP (Ground Delay Program)
ground_delays_GDP = cell2mat(GroundDelay(:, 2));

% Calcular las emisiones CO2 de los retardos en tierra del GDP (asumiendo 2.5 kg CO2 por minuto de retardo en tierra)
total_CO2_ground_GDP = sum(ground_delays_GDP) * 2.5;

% Calcular las emisiones CO2 de los retardos en aire del GDP
[~, total_CO2_air_GDP] = compute_air_emissions(AirDelay, llegadas, ARCID);

% Total de emisiones CO2 del GDP (tierra + aire)
total_CO2_GDP = total_CO2_air_GDP + total_CO2_ground_GDP;

% Total de retardos del GDP (tierra + aire)
total_delay_GDP = sum(ground_delays_GDP) + sum(cell2mat(AirDelay(:, 2)));

% Total de retardos del GHP (Ground Holding Program) - usando el coste mínimo de la Task 1
total_delay_GHP = coste_minimo;

% Total de emisiones CO2 del GHP - usando el coste de emisiones de la Task 2
total_CO2_GHP   = coste_emisiones;

% Imprimir tabla comparativa
fprintf('%-20s | %-15s | %-15s\n', 'Metric', 'GDP', 'GHP (Task 2)');
fprintf('------------------------------------------------------------\n');
fprintf('%-20s | %-15.2f | %-15.2f\n', 'Total Delay (min)',  total_delay_GDP, total_delay_GHP);
fprintf('%-20s | %-15.2f | %-15.2f\n', 'CO2 Emissions (kg)', total_CO2_GDP,   total_CO2_GHP);
fprintf('%-20s | %-15.2f | %-15.2f\n', 'CO2 saved vs GDP',   0, total_CO2_GDP - total_CO2_GHP);
fprintf('====================================================\n');