function [slots_cell, GroundDelay, AirDelay] = assign_slots(slots, Controlled, Exempt, ETA_hours, ETD_hours, ARCID)
ETA_min = (ETA_hours*60); %Convert ETA a minutes
ETD_min = (ETD_hours*60);

change_day = ETD_min > ETA_min;
ETA_min(change_day) = ETA_min(change_day)+1440; %if the flight arrives the next day we add 24h to it

slots_cell = num2cell(slots(:, 1:2));

%Matrix about delay as Cell Arrays
AirDelay = {};
GroundDelay = {};

ARCID_str = string(ARCID);
Exempt_str = string(Exempt);
Controlled_str = string(Controlled);

[~, position_exempt] = ismember(Exempt_str, ARCID_str); %returns the position of each ID inside the EXCEL file
ETA_exempt = ETA_min(position_exempt); 

%Order by ETA for let the first flight choose first
[ETA_exempt_sorted, sort_idx_exempt] = sort(ETA_exempt);
Exempt_sorted = Exempt_str(sort_idx_exempt);

for k = 1:length(Exempt_sorted)
    ID_real = char(Exempt_sorted(k));
    ETA_flight = ETA_exempt_sorted(k);
    %search the first slot available >= its ETA
    for j = 1:size(slots_cell, 1);
        if isequal(slots_cell{j,2}, 0) && slots_cell{j, 1} >= ETA_flight
            slots_cell{j, 2} = ID_real;
            %Compute the delay
            delay = slots_cell{j, 1} - ETA_flight;
            AirDelay = [AirDelay; {ID_real, delay}];
            break;
        end
    end
end

%Same proccess for the Controlled
[~, position_controlled] = ismember(Controlled_str, ARCID_str); 
ETA_controlled = ETA_min(position_controlled); 

[ETA_controlled_sorted, sort_idx_controlled] = sort(ETA_controlled);
Controlled_sorted = Controlled_str(sort_idx_controlled);

for k = 1:length(Controlled_sorted)
    ID_real = char(Controlled_sorted(k));
    ETA_flight = ETA_controlled_sorted(k);
    for j = 1:size(slots_cell, 1);
        if isequal(slots_cell{j,2}, 0) && slots_cell{j, 1} >= ETA_flight
            slots_cell{j, 2} = ID_real;
            delay = slots_cell{j, 1} - ETA_flight;
            GroundDelay = [GroundDelay; {ID_real, delay}];
            break;
        end
    end
end