function [x, coste_minimo] = solve_GHP(vuelos_opt, slots, ARCID, ETA_hours, Exempt, max_air_delay, max_ground_delay)
    % max_air_delay: máximo retardo en el aire permitido para vuelos exentos (minutos)
    N = length(vuelos_opt); % Number of flights to assign
    tiempo_slots = slots(:, 1);
    M = length(tiempo_slots); % Number of slots available
    dec_var = N * M; % Number of decision variables
    fprintf('Starting WP3 with %d flights and %d slots. \n', N, M)
    fprintf('We have %d decision variables.\n', dec_var);

    % Equality constraint: each flight assigned to exactly one slot
    Aeq1 = zeros(N, dec_var);
    for i = 1:N
        Aeq1(i, (i-1)*M + 1:i*M) = 1;
    end
    beq1 = ones(N, 1);

    % Inequality constraint: each slot assigned to at most one flight
    Aineq1 = zeros(M, dec_var);
    for j = 1:M
        Aineq1(j, j : M : dec_var) = 1;
    end
    bineq1 = ones(M, 1);

    lb = zeros(dec_var, 1);
    ub = ones(dec_var, 1);

    % Get ETA of each flight to optimize
    ETA_opt = zeros(N, 1);
    for i = 1:N
        idx = find(strcmp(ARCID, vuelos_opt{i}));
        ETA_opt(i) = ETA_hours(idx);
    end

    c = zeros(dec_var, 1); % Cost vector
    counter = 1;
    for i = 1:N
        is_exempt = any(strcmp(Exempt, vuelos_opt{i})); % True si el vuelo es exento
        for j = 1:M
            delay = tiempo_slots(j) - (ETA_opt(i) * 60);
            if tiempo_slots(j) < ETA_opt(i) * 60
                % Slot anterior a la ETA: prohibido
                ub(counter) = 0;
                c(counter)  = 0;
            elseif is_exempt && delay > max_air_delay
                ub(counter) = 0;
                c(counter)  = 0;
            elseif ~is_exempt && delay > max_ground_delay
                ub(counter) = 0;
                c(counter)  = 0;
            else
                ub(counter) = 1;
                c(counter)  = delay;
            end
            counter = counter + 1;
        end
    end

    intx = 1:dec_var;
    [x, coste_minimo] = intlinprog(c, intx, Aineq1, bineq1, Aeq1, beq1, lb, ub);
    