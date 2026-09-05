%function [outputArg1,outputArg2] = Battery_Model(inputArg1,inputArg2)
%BATTERY_MODEL Summary of this function goes here
%   Detailed explanation goes here
%outputArg1 = inputArg1;
%outputArg2 = inputArg2;
%end

%Battery New State of Charge
%Energy Stored in Battery now
%Battery DOD 
function [SOC_new,Energy_new,DOD] = Battery_Model(P, SOC_old, dt, Battery)


% Convert SOC to energy

Energy_old = SOC_old * Battery.Capacity;



%% Charging
%Positive Powerr Signifies Charging
if P > 0


    % Apply power limit

    P = min(P,Battery.Max_charge_power);


    Energy_new = Energy_old + ...
        P * Battery.Charge_efficiency * dt;



%% Discharging
%Negative Power Discharging 

elseif P < 0


    P = max(P,-Battery.Max_discharge_power);


    Energy_new = Energy_old + ...
        (P/Battery.Discharge_efficiency)*dt;



else

    Energy_new = Energy_old;

end



%% Convert Energy to SOC


SOC_new = Energy_new/Battery.Capacity;



%% Apply SOC constraints

SOC_new=max(min(SOC_new,...
    Battery.SOC_max),...
    Battery.SOC_min);



%% Depth of Discharge

DOD = 1-SOC_new;


end