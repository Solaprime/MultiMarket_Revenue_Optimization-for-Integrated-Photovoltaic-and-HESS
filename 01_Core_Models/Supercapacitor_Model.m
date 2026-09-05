


%After receiving power, what is the new voltage of the supercapacitor?

%How much energy is now stored inside it?
%This Functions returns the newVoltage and newEnergy

function [Voltage_new,Energy_new]=...
    Supercapacitor_Model(P,Voltage_old,dt,SuperCap)



C = SuperCap.Capacitance;



%% Existing energy

Energy_old = 0.5*C*Voltage_old^2;



%% Charging
%The Efficiency was not included

Energy_new = Energy_old + P*dt;



%% Voltage calculation

Voltage_new = sqrt((2*Energy_new)/C);



%% Voltage constraints
%%Take the Minimum between Voltage_new,SuperCap.Voltage_max
%%Now the Min From the Output SuperCap.Voltage_min
Voltage_new=max(min(Voltage_new,...
    SuperCap.Voltage_max),...
    SuperCap.Voltage_min);



end


%This no voltage drop due to internal resistance
%no heat loss
%no power loss

%So this is an ideal supercapacitor model, not a fully realistic one.