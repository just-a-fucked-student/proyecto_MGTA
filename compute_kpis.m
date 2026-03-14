function compute_kpis(AirDelay, GroundDelay, num_total_flights, total_CO2_air)
    
    if isempty(AirDelay)
        air_delays = 0; 
    else
        air_delays = cell2mat(AirDelay(:, 2));
    end
    
  
    if isempty(GroundDelay)
        ground_delays = 0;
    else
        ground_delays = cell2mat(GroundDelay(:, 2));
    end

    %%Total delay
    total_air = sum(air_delays);
    total_ground = sum(ground_delays);
    total_delay = total_air + total_ground;

    %%Mean delay
    air_afectados = air_delays(air_delays > 0);
    ground_afectados = ground_delays(ground_delays > 0);
    
    if isempty(air_afectados)
         mean_air = 0; 
    else
        mean_air = mean(air_afectados); 
    end
    if isempty(ground_afectados)
        mean_ground = 0; 
    else
        mean_ground = mean(ground_afectados);
    end
    
    mean_overall = total_delay / num_total_flights; 

    %%Max delay
    if isempty(air_afectados)
        max_air = 0; 
    else
        max_air = max(air_afectados)
    end
    if isempty(ground_afectados)
        max_ground = 0
    else
        max_ground = max(ground_afectados)
    end

    % 5. Relative standard deviation
    if isempty(air_afectados)
        rsd_air = 0;
    else
        rsd_air = (std(air_afectados) / mean_air) * 100;
    end
    if isempty(ground_afectados)
        rsd_ground = 0;
    else
        rsd_ground = (std(ground_afectados) / mean_ground) * 100;
    end

    %%On-time performance(
    all_delays = [air_delays; ground_delays];
    num_delayed_flights = sum(all_delays>0);
    otp_number = sum(all_delays > 0 & all_delays < 15);
    

    % 7. CO2 ground emission
    co2_ground_per_min = 2 * 3.16; 
    total_CO2_ground = total_ground * co2_ground_per_min;
    total_co2 = total_CO2_air + total_CO2_ground;

    fprintf('Delayed flights: %d flights had suffered delay\n', num_delayed_flights);
    fprintf('OTP (< 15 min): %d flights\n', otp_number);
    fprintf('Total delay: %.2f min (Air: %.2f | Ground: %.2f)\n', total_delay, total_air, total_ground);
    fprintf('Mean Delay: %.2f min/flight \n', mean_overall);
    fprintf('Mean Air: %.2f min | Mean Ground: %.2f min\n', mean_air, mean_ground);
    fprintf('Max Delay: Air: %.2f min | Ground: %.2f min\n', max_air, max_ground);
    fprintf('RSD: Air: %.2f%% | Ground: %.2f%%\n', rsd_air, rsd_ground);
    fprintf('CO2 emissions: %.2f kg extra allowed\n', total_co2);
    fprintf('(Air CO2: %.2f kg | Ground CO2: %.2f kg)\n', total_CO2_air, total_CO2_ground);
end