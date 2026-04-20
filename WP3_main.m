main;

fprintf('\n\n------------------------------------\n')
fprintf('---WP3---\n')

vuelos_opt = [Controlled; Exempt];
[x, coste_minimo] = solve_GHP( vuelos_opt, slots, ARCID, ETA_hours);

fprintf('The total minimum delay found is: %.2f mins\n', coste_minimo);
%PREGUNTAR ADELINE SI HAY QUE IMPRIMIR VUELOS DE EJEMPLO.