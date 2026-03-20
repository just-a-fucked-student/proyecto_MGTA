function compute_heatmaps(ARCID, ETA_hours, ETD_hours, Distances, Column_ECAC, Hstart, HNoReg, slots, llegadas)

    %Define the range of the variables
    radios_test = 0:250:3000; 
    hfiles_test = 0:1:Hstart; 

    HM_AirDelay = zeros(length(hfiles_test), length(radios_test));
    HM_CO2_Air     = zeros(length(hfiles_test), length(radios_test));
    HM_CO2_Ground  = zeros(length(hfiles_test), length(radios_test));
    HM_Unrecoverable = zeros(length(hfiles_test), length(radios_test));
    HM_GroundDelay = zeros(length(hfiles_test), length(radios_test));

    for i = 1:length(hfiles_test)
        for j = 1:length(radios_test)
            
            current_Hfile = hfiles_test(i);
            current_radius = radios_test(j);
            
            [~, ~, ~, ~, Exempt_loop, Controlled_loop] = compute_list(ARCID, ETA_hours, ETD_hours, Distances, Column_ECAC, current_Hfile, Hstart, HNoReg, current_radius);
            
            [~, GroundDelay_loop, AirDelay_loop] = assign_slots(slots, Controlled_loop, Exempt_loop, ETA_hours, ETD_hours, ARCID);
            
            [~, total_unrecov] = compute_unrecoverable_delay(GroundDelay_loop, ETD_hours, ETA_hours, ARCID, Hstart);
            
            [~, total_CO2_air_loop] = compute_air_emissions(AirDelay_loop, llegadas, ARCID);
            
            if isempty(GroundDelay_loop)
                total_ground_delay = 0;
            else
                total_ground_delay = sum(cell2mat(GroundDelay_loop(:, 2)));
            end
            total_CO2_ground_loop = total_ground_delay * (2 * 3.16);
            
            if isempty(AirDelay_loop)
                total_air_delay = 0;
            else
                total_air_delay = sum(cell2mat(AirDelay_loop(:, 2)));
            end

            HM_AirDelay(i, j) = total_air_delay;
            HM_GroundDelay(i, j) = total_ground_delay;
            HM_CO2_Air(i, j)     = total_CO2_air_loop;
            HM_CO2_Ground(i, j)  = total_CO2_ground_loop;
            HM_Unrecov(i, j)  = total_unrecov;
            
        end
    end

    str_radios = string(radios_test);
    str_hfiles = string(hfiles_test);

    figure('Name', 'Sensitivity Analysis: KPIs vs (Radius & Hfile)', 'Position', [100, 100, 1500, 800]);

    % Heatmap 1: Air Delay
    subplot(2,3,1);
    h1 = heatmap(str_radios, str_hfiles, HM_AirDelay);
    h1.Title = 'Total Air Delay (min)';
    h1.XLabel = 'Radius (km)';
    h1.YLabel = 'Hfile (Hora de publicación UTC)';
    h1.Colormap = parula;
    
    % Heatmap 2: Ground Delay
    subplot(2,3,2);
    h2 = heatmap(str_radios, str_hfiles, HM_GroundDelay);
    h2.Title = 'Total Ground Delay (min)';
    h2.XLabel = 'Radius (km)';
    h2.YLabel = 'Hfile (Hora de publicación UTC)';
    h2.Colormap = parula;

    % Heatmap 3: CO2 Emissions - Air Delay
    subplot(2,3,3);
    h3 = heatmap(str_radios, str_hfiles, round(HM_CO2_Air));
    h3.Title = 'CO2 Emissions - Air Delay(kg)';
    h3.XLabel = 'Radius (km)';
    h3.YLabel = 'Hfile (Hora de publicación UTC)';
    h3.Colormap = hot;

    % Heatmap 4 Unrecoverable Delay
    subplot(2,3,4);
    h4 = heatmap(str_radios, str_hfiles, HM_Unrecov);
    h4.Title = 'Unrecoverable Delay (min)';
    h4.XLabel = 'Radius (km)';
    h4.YLabel = 'Hfile (Hora de publicación UTC)';
    h4.Colormap = autumn;
    
    % Heatmap 5: CO2 Emissions - Ground Delay
    subplot(2,3,5);
    h5 = heatmap(str_radios, str_hfiles, round(HM_CO2_Ground));
    h5.Title = 'CO2 Emissions - Ground Delay(kg)';
    h5.XLabel = 'Radius (km)';
    h5.YLabel = 'Hfile (Hora de publicación UTC)';
    h5.Colormap = hot;

    [X, Y] = meshgrid(radios_test, hfiles_test);

    figure('Name', '3D Surface: KPIs vs (Radius & Hfile)', 'Position', [100, 100, 1500, 800]);

    % 3D 1: Air Delay
    subplot(2,3,1);
    surf(X, Y, HM_AirDelay);
    title('Total Air Delay (min)');
    xlabel('Radius (km)'); ylabel('Hfile (h)'); zlabel('Delay (min)');
    colormap parula; colorbar; 
    
    % 3D 2: Ground Delay
    subplot(2,3, 2);
    surf(X, Y, HM_GroundDelay);
    title('Total Ground Delay (min)');
    xlabel('Radius (km)'); ylabel('Hfile (h)'); zlabel('Delay (min)');
    colormap parula; colorbar;  

    % 3D 3: CO2 Emissions - Air Delay
    subplot(2,3,3);
    surf(X, Y, HM_CO2_Air);
    title('CO2 Emissions - Air Delay (kg)');
    xlabel('Radius (km)'); ylabel('Hfile (h)'); zlabel('CO2 (kg)');
    colormap hot; colorbar; 

    % 3D 3: Unrecoverable Delay
    subplot(2,3,4);
    surf(X, Y, HM_Unrecov);
    title('Unrecoverable Delay (min)');
    xlabel('Radius (km)'); ylabel('Hfile (h)'); zlabel('Delay (min)');
    colormap autumn; colorbar; 

    % 3D 5: CO2 Emissions -Ground Delay
    subplot(2,3,5);
    surf(X, Y, HM_CO2_Ground);
    title('CO2 Emissions - Ground Delay (kg)');
    xlabel('Radius (km)'); ylabel('Hfile (h)'); zlabel('CO2 (kg)');
    colormap hot; colorbar; 
end