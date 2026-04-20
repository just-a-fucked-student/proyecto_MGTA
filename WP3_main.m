main;

vuelos_opt = [Controlled; Exempt];
N = length(vuelos_opt); %number of flights to asign
tiempo_slots = slots(:, 1);
M = length(tiempo_slots); %number of slots available

dec_var = N*M; %number of decision variables
fprintf('\n\n------------------------------------\n')
fprintf('---WP3---\n')
fprintf('Starting WP3 with %d flights and %d slots. \n', N, M)
fprintf('We have %d decision variables.\n', dec_var);

%% Equalities
% Aeq * x = beq
Aeq1 = zeros(N, dec_var);
for i = 1:N
    Aeq1(i, (i-1)*M + 1:i*M) = 1; % Each flight is assigned to exactly one slot
end
beq1 = ones(N, 1);

Aeq2 = zeros(M, dec_var);
for j = 1:M
    Aeq2(j, j : M : dec_var) = 1; % Each slot is assigned to exactly one flight
end
beq2 = ones(M, 1);

% Combine equality constraints into a single matrix and vector
Aeq = [Aeq1; Aeq2];
beq = [beq1; beq2];

lb = zeros(dec_var, 1);
ub = ones(dec_var, 1);

%We need to get the ETA of the flights that we are going to optimize.
ETA_opt = zeros(N, 1);
for i = 1:N
    idx = find(strcmp(ARCID, vuelos_opt{i})); %Search in the original list where the flight is.
    ETA_opt(i) = ETA_hours(idx); %We keep the ETA.
end 

c = zeros(dec_var, 1); %Vector of costs c
counter = 1; %Will indicate in which variable we are
for i = 1:N
    for j = 1:M
        delay = tiempo_slots(j) - (ETA_opt(i)*60);
        if delay < 0
            c(counter) = 1e6;
        else 
            c(counter) = delay; % Assign the delay cost
        end
        counter = counter + 1; 
    end
end

intx = 1:dec_var;
[x,coste_minimo] = intlinprog(c, intx, [], [], Aeq, beq, lb, ub);
fprintf('The total minimum delay found is: %.2f mins\n', coste_minimo);