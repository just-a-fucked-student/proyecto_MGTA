function [HNoReg, delay] = calcular_regulacion(ETA, Hstart, Hend, PAAR, AAR)
    %Funcion para calcular la hora de final de regulacion y hacer el
    %grafico de aggregate demand
    if max(ETA) <= 1
        ETA_hores = ETA * 24; 
    else
        ETA_hores = ETA; 
    end
    minutos_dia = (0:1440)';
    
    % DEMANDA AGREGADA
    vols_per_minut = histcounts(ETA_hores * 60, [minutos_dia', 1442]);
    AggregateDemand = [minutos_dia, cumsum(vols_per_minut)'];
    
    %Cálculo de capacidades nominal y reducida
    Cap_Red = zeros(1441, 1); 
    Cap_Nom = zeros(1441, 1);
    Cap_Red(1) = AggregateDemand(1, 2); 
    Cap_Nom(1) = AggregateDemand(1, 2);
    
    for i = 2:1441
        t = minutos_dia(i) / 60;
        r_nom = AAR / 60;
        Cap_Nom(i) = min(Cap_Nom(i-1) + r_nom, AggregateDemand(i, 2));
        
        if t >= Hstart && t < Hend
            r_red = PAAR / 60; 
        else
            r_red = AAR / 60; 
        end
        Cap_Red(i) = min(Cap_Red(i-1) + r_red, AggregateDemand(i, 2));
    end
    
    % Cálculo Delay y HNoReg
    delay = sum(AggregateDemand(:, 2) - Cap_Red);
    idx_recuperacion = find(minutos_dia/60 >= Hend & Cap_Red >= AggregateDemand(:, 2), 1);
    if isempty(idx_recuperacion)
        HNoReg = 24; 
    else
        HNoReg = minutos_dia(idx_recuperacion)/60; 
    end
    %Cálculo average delay
    total_vuelos = AggregateDemand(end, 2);
    average_delay = delay / total_vuelos;
    
    %Plot
    figure; 
    hold on; 
    grid on;
    
    p_dem = plot(minutos_dia/60, AggregateDemand(:, 2), 'k', 'LineWidth', 2.5);
     
    idx_start = find(minutos_dia/60 >= Hstart, 1);
    p_nom = plot(minutos_dia(idx_start:end)/60, Cap_Nom(idx_start:end), 'k--', 'LineWidth', 1.5);
    
    idx_end = find(minutos_dia/60 >= Hend, 1);
    idx_noreg = find(minutos_dia/60 >= HNoReg, 1);
    
    p_red_restr = plot(minutos_dia(idx_start:idx_end)/60, Cap_Red(idx_start:idx_end), 'k:', 'LineWidth', 2.5);
    
    if ~isempty(idx_noreg) && idx_noreg > idx_end
        p_red_recov = plot(minutos_dia(idx_end:idx_noreg)/60, Cap_Red(idx_end:idx_noreg), 'k--', 'LineWidth', 2);
    end
    

    uistack(p_dem, 'top');
    title('Aggregate demand'); xlabel('Time in UTC (hour)'); ylabel('demand (Number of aircraft)');
    xlim([2 24]);
    legend([p_dem, p_red_restr, p_nom], {'Aggregate demand', 'Capacity reduced', 'Capacity nominal'}, 'Location', 'northwest');
    
    fprintf('HNoReg: %.2f h | Total Delay: %.2f min\n', HNoReg, delay);
    fprintf('Average Delay per Flight: %.2f min\n', average_delay);

    
    
end