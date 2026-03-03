function slots = compute_slots(Hstart, Hend, HNoReg, PAAR, AAR)
% compute_slots (WP1)
% Crea la matriz de slots desde Hstart hasta HNoReg (en minutos).
% Cada fila: [inicio_slot_min, idVuelo, airline]
% Al principio idVuelo y airline son 0.

    % Pasar horas a minutos
    startMin = round(Hstart * 60);
    endRedMin = round(Hend * 60);
    endRegMin = round(HNoReg * 60);

    % Tamaño de slot (minutos por llegada)
    slotReduced = 60 / PAAR;   % dentro de la ventana reducida
    slotNominal = 60 / AAR;    % fuera de la ventana reducida

    % Inicializar
    current = startMin;
    slots = [];

    % Crear slots hasta HNoReg
    while current <= endRegMin

        % Si estamos en periodo reducido -> slotReduced, si no -> slotNominal
        if current <= endRedMin
            slotSize = slotReduced;
        else
            slotSize = slotNominal;
        end

        % Añadir una fila (3 columnas)
        slots = [slots; round(current), 0, 0]; %#ok<AGROW>

        % Avanzar al siguiente slot
        current = round(current + slotSize);
    end
end