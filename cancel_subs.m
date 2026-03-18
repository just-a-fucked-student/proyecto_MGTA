function [slots2, GroundDelay2, cancelledFlights, KPI] = ...
    cancel_subs(slots, ETA, airlineList, GroundDelay, delayThreshold, chosenAirline)

    slots2 = slots;
    cancelledFlights = {};
    ARCID_str = string(airlineList);
    ETA_min = ETA * 60;

    %% 1. Identificar vuelos a cancelar
    for k = 1:size(GroundDelay, 1)
        flightID = GroundDelay{k, 1};
        delayMin = GroundDelay{k, 2};
        if strcmp(get_airline_code(char(flightID)), chosenAirline) && delayMin > delayThreshold
            cancelledFlights{end+1} = char(flightID);
        end
    end

    %% 2. Vaciar slots y guardar aerolinea original
    slotOriginalAirline = cell(size(slots2, 1), 1);
    for i = 1:length(cancelledFlights)
        f = cancelledFlights{i};
        row = find(strcmp(slots2(:, 2), f), 1);
        if ~isempty(row)
            slotOriginalAirline{row} = get_airline_code(f);
            slots2{row, 2} = 0;
        end
    end

    %% 3. Compression global (incluye preferencia por aerolinea original)
    slots2 = apply_compression_global(slots2, ETA_min, ARCID_str, slotOriginalAirline);

    %% 4. Recalcular GroundDelay2
    GroundDelay2 = {};
    for r = 1:size(slots2, 1)
        flightID = slots2{r, 2};
        if ~isequal(flightID, 0)
            slotTime = slots2{r, 1};
            [~, idx] = ismember(string(flightID), ARCID_str);
            if idx > 0
                newDelay = slotTime - ETA_min(idx);
                if newDelay < 0
                    error('Error: el vuelo %s ha sido asignado antes de su ETA.', char(flightID));
                end
                GroundDelay2 = [GroundDelay2; {char(flightID), newDelay}];
            end
        end
    end

    if ~isempty(GroundDelay2)
        [~, ord] = sort(GroundDelay2(:, 1));
        GroundDelay2 = GroundDelay2(ord, :);
    end

    %% 5. KPIs
    KPI = struct();
    KPI.numCancelled = length(cancelledFlights);
    KPI.numEmptySlotsAfter = sum(cellfun(@(x) isequal(x, 0), slots2(:, 2)));

    oldDelaysAirline = [];
    newDelaysAirline = [];

    for i = 1:size(GroundDelay, 1)
        f = char(GroundDelay{i, 1});
        if strcmp(get_airline_code(f), chosenAirline) && ~ismember(f, cancelledFlights)
            oldDelaysAirline(end+1) = GroundDelay{i, 2};
        end
    end

    for i = 1:size(GroundDelay2, 1)
        f = char(GroundDelay2{i, 1});
        if strcmp(get_airline_code(f), chosenAirline)
            newDelaysAirline(end+1) = GroundDelay2{i, 2};
        end
    end

    if isempty(oldDelaysAirline)
        KPI.meanDelay_before = 0; KPI.totalDelay_before = 0; KPI.maxDelay_before = 0;
    else
        KPI.meanDelay_before = mean(oldDelaysAirline);
        KPI.totalDelay_before = sum(oldDelaysAirline);
        KPI.maxDelay_before = max(oldDelaysAirline);
    end

    if isempty(newDelaysAirline)
        KPI.meanDelay_after = 0; KPI.totalDelay_after = 0; KPI.maxDelay_after = 0;
    else
        KPI.meanDelay_after = mean(newDelaysAirline);
        KPI.totalDelay_after = sum(newDelaysAirline);
        KPI.maxDelay_after = max(newDelaysAirline);
    end

    KPI.delayReduction = KPI.totalDelay_before - KPI.totalDelay_after;
end


function slots = apply_compression_global(slots, ETA_min, ARCID_str, slotOriginalAirline)
    changed = true;
    while changed
        changed = false;

        for i = 1:size(slots, 1)
            if isequal(slots{i, 2}, 0)
                emptyTime   = slots{i, 1};
                origAirline = slotOriginalAirline{i};
                bestRow = [];

                % Paso 1: siguiente vuelo de la misma aerolinea
                if ~isempty(origAirline)
                    for j = i+1:size(slots, 1)
                        flightID = slots{j, 2};
                        if ~isequal(flightID, 0)
                            [~, idx] = ismember(string(flightID), ARCID_str);
                            if strcmp(get_airline_code(char(flightID)), origAirline) && ...
                               idx > 0 && emptyTime >= ETA_min(idx)
                                bestRow = j;
                                break;
                            end
                        end
                    end
                end

                % Paso 2: cualquier vuelo disponible
                if isempty(bestRow)
                    for j = i+1:size(slots, 1)
                        flightID = slots{j, 2};
                        if ~isequal(flightID, 0)
                            [~, idx] = ismember(string(flightID), ARCID_str);
                            if idx > 0 && emptyTime >= ETA_min(idx)
                                bestRow = j;
                                break;
                            end
                        end
                    end
                end

                % Mover el vuelo
                if ~isempty(bestRow)
                    slotOriginalAirline{bestRow} = slotOriginalAirline{i};
                    slotOriginalAirline{i}       = '';
                    slots{i, 2}       = slots{bestRow, 2};
                    slots{bestRow, 2} = 0;
                    changed = true;
                end
            end

            if changed, break; end
        end
    end
end