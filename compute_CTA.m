function CTA_hours = compute_CTA(ARCID, ETA_hours, GroundDelay, AirDelay)
    
    %First the CTA=ETA
    CTA_min = (ETA_hours * 60);
    
    all_delays = [GroundDelay; AirDelay];
    
    ARCID_str = string(ARCID);

    for i = 1:size(all_delays, 1)
        id_delay = string(all_delays{i, 1});
        minutes_delay = all_delays{i, 2};
        
        [~, position] = ismember(id_delay, ARCID_str);
        
        if position > 0
            CTA_min(position) = CTA_min(position) + minutes_delay;
        end
    end
    
    CTA_hours = CTA_min / 60;
    
end