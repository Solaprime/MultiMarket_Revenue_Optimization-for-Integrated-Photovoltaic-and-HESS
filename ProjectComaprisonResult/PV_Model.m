function PV_Power = PV_Model(Irradiance, PV_Rated_Power)

% PV_Model
% Calculates PV output power


Reference_Irradiance = 1000;


PV_Power = PV_Rated_Power .* ...
           (Irradiance ./ Reference_Irradiance);


% Prevent negative power

PV_Power(PV_Power < 0)=0;


end