function [NotAffected, ExemptRadius, ExemptInternational, ExemptFlying, Exempt, Controlled] = compute_list(ARCID, ETA, ETD, Distances, International, Hfile, Hstart, HNoReg, radius)

margin = 0.5; %value of the margin for flights that are ready to take off

NotAffected = [];
ExemptRadius = [];    
ExemptInternational = [];
ExemptFlying = [];
Exempt = [];
Controlled = [];

num_flights = length(ETA);

%---Analyze the flights---
for i = 1:num_flights
    ID_flight = ARCID(i);
    ETA_flight = ETA(i);
    ETD_flight = ETD(i);
    DIST_flight = Distances(i);
    ECAC_flight = International(i);
    if ETA_flight<Hstart || ETA_flight >= HNoReg %Out of regulation time
        NotAffected = [NotAffected; ID_flight];
    else %Here, the flights are inside the rgulation
        is_exempt = false;
        if DIST_flight > radius %flight outside the radius
            ExemptRadius = [ExemptRadius; ID_flight];
            is_exempt = true;
        end
        if ETD_flight <= (Hfile + margin)||(ETD_flight > ETA_flight) %flight already flying
            ExemptFlying = [ExemptFlying; ID_flight];
            is_exempt = true;
        end
        if strcmpi(ECAC_flight, 'NO ECAC')
            ExemptInternational = [ExemptInternational; ID_flight];
            is_exempt = true;
        end
        if is_exempt == true
            Exempt = [Exempt; ID_flight];
        else
            Controlled = [Controlled; ID_flight];
        end
    end
end


