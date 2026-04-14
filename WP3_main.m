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