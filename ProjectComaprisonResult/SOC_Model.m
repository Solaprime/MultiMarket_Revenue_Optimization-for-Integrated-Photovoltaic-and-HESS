function SOC = SOC_Model(Battery_Power,...
    Initial_SOC,...
    Battery_Capacity,...
    Efficiency,...
    Time_Step)
% SOC_Model
% Calculates battery State of Charge
SOC = zeros(size(Battery_Power));
SOC(1)=Initial_SOC;
%%Start a loop From 2
for k=2:length(Battery_Power)
    Energy_Change = ...
        Battery_Power(k) * Time_Step;
if Battery_Power(k) >= 0
% Charging
        Energy_Change = ...
        Energy_Change * Efficiency;
else
% Discharging
        Energy_Change = ...
        Energy_Change / Efficiency;
end
    SOC(k)=SOC(k-1)+ ...
        (Energy_Change / Battery_Capacity)*100;
% SOC limits                        ← CHANGED: removed Battery_SOC_Max
if SOC(k) > 100                    %   and Battery_SOC_Min variables
        SOC(k) = 100;              %   replaced with hardcoded values
end                                %   because those variables are not
if SOC(k) < 0                      %   passed into this function
        SOC(k) = 0;
end
end
end