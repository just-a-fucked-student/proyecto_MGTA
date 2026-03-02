function slots = compute_slots(Hstart1, Hend1, Hstart2, Hend2, HNoReg, PAAR, AAR)
% Crea la matriz de slots desde Hstart1 hasta HNoReg (en minutos)
% Cada fila: [inicio_slot_min, idVuelo, airline]
% idVuelo y airline empiezan en 0.

    start1 = round(Hstart1*60);  end1 = round(Hend1*60);
    start2 = round(Hstart2*60);  end2 = round(Hend2*60);
    endReg = round(HNoReg*60);

    % Tamaños de slot (minutos por llegada)
    slotA = 60 / AAR;
    slotP = 60 / PAAR;

    % Empezamos en el inicio de regulación
    current = start1;

    slots = [];  % iremos añadiendo filas

    while current <= endReg
        % Decidir si estamos en periodo reducido o no
        if (current >= start1 && current <= end1) || (current >= start2 && current <= end2)
            slotSize = slotP;
        else
            slotSize = slotA;
        end

        % Añadir slot: [inicio, 0, 0]
        slots = [slots; round(current), 0, 0];

        % Avanzar al siguiente slot
        current = round(current + slotSize); 
        % slots en minutos enteros
    end
end