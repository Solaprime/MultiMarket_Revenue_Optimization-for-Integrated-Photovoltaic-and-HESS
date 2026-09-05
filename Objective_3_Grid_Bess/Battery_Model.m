function Battery_Power = Battery_Model(Ppv, Pload, ...
    Max_Charge, Max_Discharge)

% Battery_Model
% Determines battery charging and discharging power


Power_Balance = Ppv - Pload;


Battery_Power = zeros(size(Ppv));


for k = 1:length(Ppv)


    % Excess PV available
    % Battery charges

    if Power_Balance(k) > 0


        Battery_Power(k) = min( ...
            Power_Balance(k), ...
            Max_Charge);


    % PV cannot satisfy load
    % Battery discharges

    elseif Power_Balance(k) < 0


        Battery_Power(k) = -min( ...
            abs(Power_Balance(k)), ...
            Max_Discharge);


    else

        Battery_Power(k)=0;


    end


end


end