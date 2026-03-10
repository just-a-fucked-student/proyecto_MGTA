function [UnrecoverableDelay, total_unrecoverable] = compute_unrecoverable_delay(GroundDelay, ETD_hours, ETA_hours, ARCID, Hstart)
    Hstart_min = Hstart * 60;
    
    
    UnrecoverableDelay = cell(size(GroundDelay, 1), 2);
    total_unrecoverable = 0;
    
    ARCID_str = string(ARCID);
    
    for i = 1:size(GroundDelay, 1)
        id_flight = string(GroundDelay{i, 1});
        assigned_delay = GroundDelay{i, 2};
        
        % Find flight position on original data
        [~, idx] = ismember(id_flight, ARCID_str);
        
        if idx > 0
            ETD_min = ETD_hours(idx) * 60;
            ETA_min = ETA_hours(idx) * 60;
            
            %If the flight took off on the day before
            if ETD_min > ETA_min
                ETD_min = ETD_min - (24 * 60);
            end
            
            
            CTD_min = ETD_min + assigned_delay;
            
            % Apply three different cases
            if ETD_min >= Hstart_min
                % Case 1: ETD > Hstart -> recoverable delay
                unrecov = 0;
            elseif CTD_min <= Hstart_min
                % Case 2: CTD < Hstart -> unrecoverable delay 
                unrecov = assigned_delay; 
            else
                % Case 3: ETD < Hstart i CTD > Hstart -> parcial
                % unrecoverable delay
                unrecov = Hstart_min - ETD_min;
            end
            
            % Save at the matrix
            UnrecoverableDelay{i, 1} = char(id_flight);
            UnrecoverableDelay{i, 2} = unrecov;
            
            total_unrecoverable = total_unrecoverable + unrecov;
        end
    end
end