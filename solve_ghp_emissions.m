function [x, coste_minimo] = solve_ghp_emissions(vuelos_opt, slots, ARCID, ETA_hours, llegadas, Exempt, max_air_delay)
    % max_air_delay:    máximo retardo en el aire permitido para vuelos exentos (minutos)
    % max_ground_delay: máximo retardo en tierra permitido para vuelos controlados (minutos)
    % Justificación: delays en tierra >3h generan reactionary delays significativos (slide 7 PDF)
    max_ground_delay = 360;

    %% Pre-calcular las emisiones de cada vuelo (kg CO2 por minuto de retardo)
    N = length(vuelos_opt); % Número de vuelos a asignar
    tiempo_slots = slots(:, 1);
    M = length(tiempo_slots); % Número de slots disponibles
    dec_var = N * M; % Número de variables de decisión (una por cada par vuelo-slot)
    fprintf('Starting WP3 Emissions with %d flights and %d slots. \n', N, M);
    fprintf('We have %d decision variables.\n', dec_var);

    % Extraer columnas necesarias de la tabla de llegadas
    ARCID_str = string(ARCID);
    distances = llegadas.Flight_Distance_km_;
    seats = llegadas.Seats;
    ETA_h = llegadas.ETA * 24; % ETA en horas del día
    ETD_H = llegadas.ETD * 24; % ETD en horas del día

    emissions_per_min = zeros(N, 1); % Vector de tasa de emisiones por vuelo (kg CO2/min)

    for i = 1:N
        id_flight = string(vuelos_opt{i});
        [~, idx] = ismember(id_flight, ARCID_str); % Buscar el vuelo en la tabla original

        if idx > 0
            dist = distances(idx);
            seat_count = seats(idx);
            if isnan(seat_count) || seat_count == 0
                seat_count = 150; % Valor por defecto si faltan datos de asientos
            end

            % Calcular tiempo de vuelo y velocidad media
            eta_f = ETA_h(idx);
            etd_f = ETD_H(idx);
            if etd_f > eta_f
                etd_f = etd_f - 24; % Ajustar si el vuelo despegó el día anterior
            end
            flight_time = eta_f - etd_f; % Duración del vuelo en horas
            if flight_time <= 0
                flight_time = dist / 800; % Fallback: asumir velocidad crucero de 800 km/h
            end

            velocity_km_h = dist / flight_time;  % Velocidad media en km/h
            km_per_min = velocity_km_h / 60;      % Velocidad en km/min

            % Tasa de emisiones depende del tipo de retardo (air vs ground)
            is_exempt = any(strcmp(Exempt, vuelos_opt{i}));

            if is_exempt
                % Vuelo exento: hace air delay en crucero → usar modelo de emisiones
                try
                    fuel_ask_g = emissions_fuel_model.compute_fuel_ask(dist, seat_count);
                catch
                    fuel_ask_g = 16.0; % Fallback si falla el modelo (~16 g/ASK típico)
                end
                co2_ask = (fuel_ask_g / 1000) * 3.16; % kg CO2/ASK (factor conversión combustible→CO2)
                co2_per_km = co2_ask * seat_count;      % kg CO2 por km del vuelo completo
                emissions_per_min(i) = co2_per_km * km_per_min; % kg CO2/min en crucero
            else
                % Vuelo controlado: hace ground delay (motor al ralentí) → tasa fija estándar
                emissions_per_min(i) = 2.5; % kg CO2/min en tierra (valor estándar EUROCONTROL)
            end
        else
            emissions_per_min(i) = 0.042; % Fallback si no se encuentra el vuelo en la tabla
        end
    end

    %% Restricciones del problema de asignación
    % Restricción de igualdad: cada vuelo se asigna a exactamente un slot
    Aeq1 = zeros(N, dec_var);
    for i = 1:N
        Aeq1(i, (i-1)*M + 1:i*M) = 1;
    end
    beq1 = ones(N, 1);

    % Restricción de desigualdad: cada slot admite como máximo un vuelo
    Aineq1 = zeros(M, dec_var);
    for j = 1:M
        Aineq1(j, j : M : dec_var) = 1;
    end
    bineq1 = ones(M, 1);

    % Bounds: variables binarias (0 = no asignado, 1 = asignado)
    lb = zeros(dec_var, 1);
    ub = ones(dec_var, 1);

    % Extraer la ETA de cada vuelo a optimizar desde la lista original
    ETA_opt = zeros(N, 1);
    for i = 1:N
        idx = find(strcmp(ARCID, vuelos_opt{i}));
        ETA_opt(i) = ETA_hours(idx);
    end

    % Vector de costes: para cada par (vuelo i, slot j) el coste es kg CO2 generados por ese retardo
    c = zeros(dec_var, 1);
    counter = 1; % Índice de la variable de decisión actual
    for i = 1:N
        is_exempt = any(strcmp(Exempt, vuelos_opt{i})); % True si el vuelo es exento
        for j = 1:M
            delay = tiempo_slots(j) - (ETA_opt(i) * 60); % Retardo en minutos si se asigna este slot
            if tiempo_slots(j) < ETA_opt(i) * 60
                ub(counter) = 0;        % Slot anterior a la ETA: prohibido
                c(counter)  = 0;
            elseif is_exempt && delay > max_air_delay
                ub(counter) = 0;        % Air delay excesivo para vuelo exento: prohibido
                c(counter)  = 0;
            elseif ~is_exempt && delay > max_ground_delay
                ub(counter) = 0;        % Ground delay excesivo para vuelo controlado: prohibido
                c(counter)  = 0;
            else
                ub(counter) = 1;
                c(counter)  = emissions_per_min(i) * delay; % Coste = kg CO2/min * minutos de retardo
            end
            counter = counter + 1;
        end
    end

    % Resolver el problema entero mixto con intlinprog
    intx = 1:dec_var;
    [x, coste_minimo] = intlinprog(c, intx, Aineq1, bineq1, Aeq1, beq1, lb, ub);
end
