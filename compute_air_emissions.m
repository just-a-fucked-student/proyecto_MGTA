function [AirEmissions, total_CO2_air_delay] = compute_air_emissions(AirDelay, llegadas, ARCID)
    % Initialize variables
    AirEmissions = cell(size(AirDelay, 1), 2);
    total_CO2_air_delay = 0;
    ARCID_str = string(ARCID);
    
    % Extract data from Excel
    distances = llegadas.Flight_Distance_km_;
    seats = llegadas.Seats; 
    ETA_hours = llegadas.ETA * 24;
    ETD_hours = llegadas.ETD * 24;
    
    for i = 1:size(AirDelay, 1)
        id_flight = string(AirDelay{i, 1});
        delay_min = AirDelay{i, 2};
        
        if delay_min > 0
            % Find which Excel row corresponds to this flight
            [~, idx] = ismember(id_flight, ARCID_str);
            
            if idx > 0
                dist = distances(idx);
                seat_count = seats(idx);
                
                % Error handling for missing seats
                if isnan(seat_count) || seat_count == 0
                    seat_count = 150; 
                end
                
                %Calculate flight time and speed
                eta_f = ETA_hours(idx);
                etd_f = ETD_hours(idx);
                
                % Adjustment for flights that departed the previous day
                if etd_f > eta_f
                    etd_f = etd_f - 24; 
                end
                
                flight_time_hours = eta_f - etd_f;
                
                % Safety check for data errors
                if flight_time_hours <= 0
                    flight_time_hours = dist / 800; 
                end
                
                velocity_km_h = dist / flight_time_hours;
                km_per_min = velocity_km_h / 60;
                
                %Call the emissions model (Returns GRAMS per ASK)
                try
                    fuel_ask_grams = emissions_fuel_model.compute_fuel_ask(dist, seat_count);
                catch
                    fuel_ask_grams = 16.0; % Fallback to typical ~16 grams/ASK
                end
                
                %Convert grams to kg and calculate CO2
                fuel_ask_kg = fuel_ask_grams / 1000;
                co2_ask = fuel_ask_kg * 3.16;
                
                co2_per_km = co2_ask * seat_count;
                co2_per_min = co2_per_km * km_per_min;
                
                %Multiply CO2 per min by the air delay
                flight_air_co2 = co2_per_min * delay_min;
                

                % Save data
                AirEmissions{i, 1} = char(id_flight);
                AirEmissions{i, 2} = flight_air_co2;
                total_CO2_air_delay = total_CO2_air_delay + flight_air_co2;
            end
        else
            % If it has no Air Delay
            AirEmissions{i, 1} = char(id_flight);
            AirEmissions{i, 2} = 0;
        end
    end
end