function [HNoReg, totalDelay] = calcular_regulacion(ETA, Hstart1, Hend1, Hstart2, Hend2, PAAR, AAR)
% WP1 - Version sencilla y correcta: acumulamos desde el inicio de regulacion (Hstart1)

    % 1) ETA a minutos del día
    ETA_min = round(mod(ETA * 24 * 60, 1440));   % 0..1440

    % 2) Pasar horas a minutos
    start1 = round(Hstart1*60);  end1 = round(Hend1*60);
    start2 = round(Hstart2*60);  end2 = round(Hend2*60);

    % 3) Tiempo de análisis: desde start1 hasta fin del día
    t = (start1:1440)';                 % minutos
    nT = length(t);

    % 4) DEMANDA por minuto (solo contamos llegadas desde start1 en adelante)
    arrivalsPerMin = zeros(nT,1);
    for i = 1:length(ETA_min)
        m = ETA_min(i);
        if m >= start1 && m <= 1440
            idx = (m - start1) + 1;     % convertir minuto real a índice de vector t
            arrivalsPerMin(idx) = arrivalsPerMin(idx) + 1;
        end
    end

    % 5) CAPACIDAD por minuto (desde start1)
    capPerMin = zeros(nT,1);
    for k = 1:nT
        minutoReal = t(k);

        if (minutoReal >= start1 && minutoReal <= end1) || (minutoReal >= start2 && minutoReal <= end2)
            capPerMin(k) = PAAR/60;
        else
            capPerMin(k) = AAR/60;
        end
    end

    % 6) Acumuladas (como piden las slides)
    DemandCum   = cumsum(arrivalsPerMin);
    CapacityCum = cumsum(capPerMin);

    % 7) Cola / backlog y delay mínimo total
    Backlog = DemandCum - CapacityCum;
    Backlog(Backlog < 0) = 0;

    totalDelay = sum(Backlog);

    % 8) HNoReg = primer minuto despues del final de la 2ª ventana donde backlog = 0
    HNoReg = NaN;
    for minutoReal = (end2+1):1440
        k = (minutoReal - start1) + 1;
        if k >= 1 && k <= nT && Backlog(k) == 0
            HNoReg = minutoReal/60;
            break
        end
    end
    if isnan(HNoReg)
        HNoReg = 24;
    end

    % 9) Plot de verificación
    figure;
    plot(t/60, DemandCum, 'LineWidth', 2); hold on;
    plot(t/60, CapacityCum, 'LineWidth', 2);
    grid on;
    xlabel('Time (UTC hours)');
    ylabel('Cumulative arrivals (from Hstart1)');
    legend('Aggregate Demand','Aggregate Capacity','Location','best');
    title('WP1 - Aggregate demand vs capacity (from start of regulation)');

end