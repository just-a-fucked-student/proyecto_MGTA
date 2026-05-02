function [x, coste_minimo] = solve_GHP_costs(vuelos_opt, slots, tabla, Exempt, max_air_delay)
  
    ARCID = tabla.ARCID;
    ETA_hours = tabla.ETA;
    ETD_hours = tabla.ETD;
    Seats = tabla.Seats;
    RM = tabla.RM;

    N = length(vuelos_opt); % Number of flights to assign
    tiempo_slots = slots(:, 1);
    M = length(tiempo_slots); % Number of slots available
    dec_var = N * M; % Number of decision variables
    
    fprintf('Starting GHP: Minimum Delay Cost\n');

    %% Equality constraint: each flight assigned to exactly one slot
    Aeq = zeros(N, dec_var);
    for i = 1:N
        Aeq(i, (i-1)*M + 1:i*M) = 1;
    end
    beq = ones(N, 1);

    %% Inequality constraint: each slot assigned to at most one flight
    Aineq = zeros(M, dec_var);
    for j = 1:M
        Aineq(j, j : M : dec_var) = 1;
    end
    bineq = ones(M, 1);
    
    %% Boundaries
    lb = zeros(dec_var, 1);
    ub = ones(dec_var, 1);
    
    %% Flight Data
    ETA_opt   = zeros(N,1);
    ETD_opt   = zeros(N,1);
    Seats_opt = zeros(N,1);
    RM_opt    = cell(N,1);

    for i = 1:N
        idx = find(strcmp(ARCID,vuelos_opt{i}),1);
        ETA_opt(i) = ETA_hours(idx);
        ETD_opt(i) = ETD_hours(idx);
        Seats_opt(i) = Seats(idx);
        RM_opt{i} = RM{idx};

    end

    %% Basic reactionary multipliers by delay magnitude(Table 19 Tanner and Cook)
    cook_delay_min  = [0, 5, 15, 30, 60, 90, 120, 180, 240, 300];
    cook_react_mult = [1.0, 1.52, 1.70, 1.97, 2.51, 3.05, 3.60, 4.68, 5.77, 6.85];
    
    %% Valores promedio B738 y A320
    cook_delay = [5, 15, 30, 60, 90, 120, 180, 240, 300];
    % AT-GATE / BASE / primary tactical costs (Table 22 Tanner and Cook)
    cook_cost_ground = [95, 470, 1400, 4750, 9400, 15070, 29480, 47795, 69790];

    % EN-ROUTE / BASE / primary tactical costs (Table 24 Tanner and Cook)
    cook_cost_airborne = [270, 995, 2490, 6865, 12565, 19310, 35840, 56275, 80390];
    
    %% Cost Vector
    c = zeros(dec_var, 1); % Cost vector
    counter = 1;
    
    for i = 1:N
        is_exempt = any(strcmp(Exempt, vuelos_opt{i}));
        ETA   = ETA_opt(i)*1440;
        seats = Seats_opt(i);
        rm    = RM_opt{i};
        
        pax = 0.85 * seats; %Load factor recommended by eurocontrol

        % Turnaround multiplier using same aircraft RM
        same_aircraft = strcmp(RM,rm);
        future_dep = ETD_hours(same_aircraft)*1440; %ETD in minutes
        future_dep = future_dep(future_dep > ETA); %Only departures afetr arriving
    
        has_rotation = ~isempty(future_dep);
        turnaround = Inf;
        if has_rotation
            turnaround = min(future_dep) - ETA;   % minutes available
        end
        %% SLOT LOOP
        for j = 1:M
            delay = tiempo_slots(j) - ETA;
            % Slot before ETA -> infeasible
            if tiempo_slots(j) < ETA
                ub(counter) = 0;
                c(counter)  = 1e6;
    
            % Exempt flights max air delay
            elseif is_exempt && delay > max_air_delay
                ub(counter) = 0;
                c(counter)  = 1e6;

            %If there is no delay there is no cost    
            elseif delay == 0
                c(counter) = 0;
            else
                delay_clamped = max(5, min(delay,300));
                if is_exempt %Airbone delay
                    op_cost = interp1(cook_delay, cook_cost_airborne, delay_clamped, 'pchip');
                else 
                    op_cost = interp1(cook_delay, cook_cost_ground, delay_clamped, 'pchip');
                end
                % We take as reference a standard flight with 128 pax
                % (narrowbody with LF of 0.85)
                pax_ref = 128;
                factor = pax / pax_ref;
                op_cost = op_cost * factor;

                %reactionary multiplier
                react_mult = 1.0;
                if has_rotation && delay > turnaround %more delay tham turnaround: reactionary
                    react_mult = interp1(cook_delay_min, cook_react_mult, delay_clamped, 'pchip', 'extrap');
                    react_mult = max(1.0, react_mult);
                elseif has_rotation && delay > 0 %Delay inside the turnaround, partial propagation
                    %We take 1.97 as point since is the first point where
                    %propagation grows exponentially.
                    frac = min(delay/turnaround, 1.0); %proportion of the time of the turnaround that the delay takes
                    react_mult = 1.0 + frac * (1.97 - 1.0);
                end
                c(counter) = op_cost*react_mult;  
            end
            counter = counter + 1;
        end
    end
    %% Solve the optimization
    intx = 1:dec_var;
    [x,coste_minimo] = intlinprog(c,intx,Aineq,bineq,Aeq,beq,lb,ub);
    
    %comprobacion del delay
    delay_total = 0;
        for i = 1:N
            for j = 1:M
                idx_x = (i-1)*M + j;
                if x(idx_x) <= length(x) && x(idx_x) > 0.5
                    ETA_min  = ETA_opt(i) * 1440;
                    slot_min = tiempo_slots(j);
                    delay_ij = max(0, slot_min - ETA_min);
                    delay_total = delay_total + delay_ij;
                end
            end
        end
fprintf('\nDelay total GHP costs: %.1f min\n', delay_total);
end
    

    