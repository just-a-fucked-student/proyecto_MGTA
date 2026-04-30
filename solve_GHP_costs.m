function [x, coste_minimo] = solve_GHP_costs(vuelos_opt, slots, tabla, Exempt, max_air_delay)
  
    ARCID = tabla.ARCID;
    ETA_hours = tabla.ETA;
    ETD_hours = tabla.ETD;
    Seats = tabla.Seats;
    Distancia = tabla.Flight_Distance_km_;
    RM = tabla.RM;
    ECAC = tabla.ECAC;

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
    Dist_opt  = zeros(N,1);
    ECAC_opt  = cell(N,1);
    RM_opt    = cell(N,1);

    for i = 1:N
        idx = find(strcmp(ARCID,vuelos_opt{i}),1);
        ETA_opt(i) = ETA_hours(idx);
        ETD_opt(i) = ETD_hours(idx);
        Seats_opt(i) = Seats(idx);
        Dist_opt(i) = Distancia(idx);
        ECAC_opt{i} = ECAC{idx};
        RM_opt{i} = RM{idx};

    end

    %% Cost Vector
    c = zeros(dec_var, 1); % Cost vector
    counter = 1;
    
    for i = 1:N
        is_exempt = any(strcmp(Exempt, vuelos_opt{i}));
        ETA   = ETA_opt(i)*1440;
        seats = Seats_opt(i);
        dist  = Dist_opt(i);
        ecac  = ECAC_opt{i};
        rm    = RM_opt{i};
        
        pax = 0.85 * seats; %Load factor recommended by eurocontrol
        % Connecting passengers (22% at BCN in Aena Statistics)
        pct_connect = 0.22;
        pax_connect = pax * pct_connect;
        %Compensation per passsenger (EU261)
        if dist <= 1500
            base = 250;
        elseif dist <= 3500
            base = 400;
        else
            base = 600;
        end
        
        %Ecac Condition, since non-ECAC has a bigger operational cost per
        %minute and more impact in the connections
        if strcmpi(strtrim(ecac), 'NO ECAC')
            ecac_mult = 1.25;  % non-ECAC more expensive
        else
            ecac_mult = 1.0;
        end
        
        %Threshold to set the lost conection
        connect_threshold = 50; %for BCN domestic flights is 20min while for international is 60min, we set an intermediate value(near to the international one because that are more complexes) since we don't know which flight are the passengers going to take
        
        %Operational cost depending on type of delay
        if is_exempt
            cost_per_min = 82.95; %airborne
        else 
            cost_per_min = 17.78; %ground at gate
        end

    % Turnaround multiplier using same aircraft RM
    turn_mult = 1.0;
    same_aircraft = strcmp(RM,rm);

    future_dep = ETD_hours(same_aircraft)*1440; %ETD in minutes
    future_dep = future_dep(future_dep > ETA); %Only departures afetr arriving

    if ~isempty(future_dep)
        next_dep = min(future_dep); %next departure of that flight
        turnaround = next_dep - ETA; %time availavble for turnaround

        if turnaround < 75
            turn_mult = 2.0; %very tight turnaround
        elseif turnaround < 120
            turn_mult = 1.5; %moderate turnaround
        end
    end

    %% SLOT LOOP
    for j = 1:M
        delay = tiempo_slots(j) - ETA;
        % Slot before ETA -> infeasible
        if tiempo_slots(j) < ETA
            ub(counter) = 0;
            c(counter)  = 0;

        % Exempt flights max air delay
        elseif is_exempt && delay > max_air_delay
            ub(counter) = 0;
            c(counter)  = 0;
        else
            ub(counter) = 1;
            %Operational cost: €/min * delay * ECAC multiplier
            op_cost = cost_per_min * ecac_mult;
            % Connection loss cost
            if delay > connect_threshold %if the delay is bigger than the theshold of the connection lost
                rf = op_cost * turn_mult+ (pax_connect * base) / delay;
            else
                rf = op_cost * turn_mult;
            end
            %Total cost coefficient for the flight
            c(counter) = rf * delay;
        end
        counter = counter + 1;
    end
end

%% Solve the optimization

intx = 1:dec_var;

[x,coste_minimo] = intlinprog(c,intx,Aineq,bineq,Aeq,beq,lb,ub);

%funciona?
end
    