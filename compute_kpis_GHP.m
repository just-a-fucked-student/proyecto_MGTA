function compute_kpis_GHP(x, vuelos_opt, slots, ARCID, ETA_hours, llegadas, Exempt, label, GroundDelay_GDP, AirDelay_GDP)
    %% Decodificar la solución x del solver en delays por vuelo
    % x es el vector binario de asignación devuelto por intlinprog
    % x tiene N*M elementos: x((i-1)*M + j) = 1 significa vuelo i asignado a slot j
    N = length(vuelos_opt);       % Número total de vuelos optimizados
    tiempo_slots = slots(:, 1);   % Vector de tiempos de slot en minutos desde medianoche
    M = length(tiempo_slots);     % Número de slots disponibles

    fprintf('\n========== GHP KPIs: %s ==========\n', label);

    % Inicializar celdas de delay en el mismo formato que WP2: {id, delay_min}
    % Columna 1: ID del vuelo | Columna 2: minutos de retardo
    AirDelay_GHP    = cell(N, 2); % Retardos absorbidos en el aire (vuelos exentos)
    GroundDelay_GHP = cell(N, 2); % Retardos absorbidos en tierra (vuelos controlados)

    for i = 1:N
        % Para el vuelo i, buscar qué slot j tiene x((i-1)*M + j) = 1
        slot_assigned = 0;
        for j = 1:M
            if round(x((i-1)*M + j)) == 1
                slot_assigned = tiempo_slots(j); % Tiempo del slot asignado en minutos
                break;
            end
        end

        % Delay = hora de llegada asignada - ETA original (ambos en minutos)
        delay_min = slot_assigned - ETA_hours(strcmp(ARCID, vuelos_opt{i})) * 60;
        delay_min = max(0, delay_min); % No puede ser negativo por definición

        % Clasificar el retardo según el tipo de vuelo
        is_exempt = any(strcmp(Exempt, vuelos_opt{i})); % True si el vuelo es exento

        if is_exempt
            % Vuelo exento: no se puede retener en tierra, el retardo va al aire
            AirDelay_GHP{i, 1}    = vuelos_opt{i};
            AirDelay_GHP{i, 2}    = delay_min;
            GroundDelay_GHP{i, 1} = vuelos_opt{i};
            GroundDelay_GHP{i, 2} = 0;
        else
            % Vuelo controlado: se retiene en origen, el retardo es en tierra
            AirDelay_GHP{i, 1}    = vuelos_opt{i};
            AirDelay_GHP{i, 2}    = 0;
            GroundDelay_GHP{i, 1} = vuelos_opt{i};
            GroundDelay_GHP{i, 2} = delay_min;
        end
    end

    %% KPIs generales: reutilizamos compute_kpis de WP2
    num_total_flights = length(ARCID); % Total de vuelos del día (no solo los optimizados)

    % Calcular CO2 real del air delay usando el modelo de emisiones de WP2
    [~, total_CO2_air_GHP] = compute_air_emissions(AirDelay_GHP, llegadas, ARCID);
    compute_kpis(AirDelay_GHP, GroundDelay_GHP, num_total_flights, total_CO2_air_GHP);

    fprintf('\n--- Airline-level KPIs (Top 4) ---\n');

    % Delay total por vuelo sumando air y ground
    all_delays_GHP = cell2mat(AirDelay_GHP(:,2)) + cell2mat(GroundDelay_GHP(:,2));

    % Extraer el código de aerolínea de cada ARCID (ej: VLG, IBE, RYR...)
    airline_codes = cell(N, 1);
    for i = 1:N
        airline_codes{i} = get_airline_code(char(vuelos_opt{i}));
    end

    % Agrupar vuelos por aerolínea y ordenar de mayor a menor número de vuelos
    [unique_al, ~, idx_al] = unique(airline_codes);
    counts   = accumarray(idx_al, 1);          % Vuelos por aerolínea
    [~, order] = sort(counts, 'descend');      % Ordenar de mayor a menor
    top_n = min(4, length(unique_al));         % Seleccionar las 4 más grandes

    fprintf('%-8s | %-10s | %-12s | %-10s\n', 'Airline', 'Flights', 'Mean Delay', 'RSD (%)');
    fprintf('--------------------------------------------------\n');

    for k = 1:top_n
        al = unique_al{order(k)};
        mask = strcmp(airline_codes, al);  % Máscara para los vuelos de esta aerolínea
        delays_al = all_delays_GHP(mask); % Delays de esa aerolínea

        mean_al = mean(delays_al);
        if mean_al > 0
            rsd_al = (std(delays_al) / mean_al) * 100; % RSD = std/mean * 100 (%)
        else
            rsd_al = 0; % Evitar división por cero si el delay medio es 0
        end

        fprintf('%-8s | %-10d | %-12.2f | %-10.2f\n', al, sum(mask), mean_al, rsd_al);
    end
    fprintf('==================================\n');

    %% Fairness: comparación GHP vs GDP a nivel de aerolínea
    fprintf('\n--- Fairness: GHP vs GDP (Top 4 airlines) ---\n');

    % Calcular delay medio por aerolínea en el GDP (usando GroundDelay + AirDelay del WP2)
    gdp_ids         = [GroundDelay_GDP(:,1); AirDelay_GDP(:,1)]; % IDs de todos los vuelos GDP
    gdp_delays_all  = [cell2mat(GroundDelay_GDP(:,2)); cell2mat(AirDelay_GDP(:,2))];

    gdp_airline_codes = cell(length(gdp_ids), 1);
    for i = 1:length(gdp_ids)
        gdp_airline_codes{i} = get_airline_code(char(gdp_ids{i}));
    end

    fprintf('%-8s | %-14s | %-14s | %-10s\n', 'Airline', 'Mean GDP (min)', 'Mean GHP (min)', 'Fairer?');
    fprintf('------------------------------------------------------------\n');

    for k = 1:top_n
        al = unique_al{order(k)};

        % Media GHP (ya calculada arriba)
        mask_ghp = strcmp(airline_codes, al);
        mean_ghp = mean(all_delays_GHP(mask_ghp));

        % Media GDP para la misma aerolínea
        mask_gdp = strcmp(gdp_airline_codes, al);
        if any(mask_gdp)
            mean_gdp = mean(gdp_delays_all(mask_gdp));
        else
            mean_gdp = 0;
        end

        % GHP es más justo si la diferencia entre aerolíneas se reduce
        if mean_ghp <= mean_gdp
            fairer = 'GHP better';
        else
            fairer = 'GDP better';
        end

        fprintf('%-8s | %-14.2f | %-14.2f | %-10s\n', al, mean_gdp, mean_ghp, fairer);
    end
    fprintf('==================================\n');

    %% Plot comparación fairness GDP vs GHP por aerolínea
    mean_gdp_plot = zeros(top_n, 1);
    mean_ghp_plot = zeros(top_n, 1);
    names_plot    = cell(top_n, 1);

    for k = 1:top_n
        al = unique_al{order(k)};
        names_plot{k} = al;

        mask_ghp = strcmp(airline_codes, al);
        mean_ghp_plot(k) = mean(all_delays_GHP(mask_ghp));

        mask_gdp = strcmp(gdp_airline_codes, al);
        if any(mask_gdp)
            mean_gdp_plot(k) = mean(gdp_delays_all(mask_gdp));
        else
            mean_gdp_plot(k) = 0;
        end
    end

    figure('Name', ['Fairness: GDP vs GHP - ' label], 'Color', 'w');
    bar([mean_gdp_plot, mean_ghp_plot]);
    set(gca, 'XTickLabel', names_plot);
    legend('GDP', ['GHP (' label ')'], 'Location', 'northeast');
    xlabel('Airline');
    ylabel('Mean Delay (min)');
    title(['Mean Delay per Airline: GDP vs GHP (' label ')']);
    grid on;
end
