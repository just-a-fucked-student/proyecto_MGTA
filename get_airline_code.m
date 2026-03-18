function code = get_airline_code(flightName)
%Sacamos el codigo de la aerolinea desde el ARCID

    if iscell(flightName)
        flightName = flightName{1};
    end
    if isstring(flightName)
        flightName = char(flightName);
    end
    if iscategorical(flightName)
        flightName = char(string(flightName));
    end
    if ~ischar(flightName)
        flightName = char(string(flightName));
    end

    pos = regexp(flightName, '\d');

    if isempty(pos)
        code = flightName;
    else
        code = flightName(1:pos(1)-1);
    end
end