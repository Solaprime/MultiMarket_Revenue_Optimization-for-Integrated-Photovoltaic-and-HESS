%This Model helps Convert Sunlight to Electricity it takes
%G -Solar irradiance and Cell Temperature as Input
%Then output PV Output Power

%Two Inputs G-Solar Irradiance,
% T-Cell Temperature
function Ppv = PV_Model(G,T,PV)


% Temperature correction
%Hotter Temperature reduces the Efficency, Power and
%Voltage of PV Cells, Hence this Temperature Correction
Temperature_factor = ...
1-PV.Temperature_Coefficient*...
(T-PV.Reference_Temperature);



% PV output

Ppv = PV.Rated_Power*...
(G/PV.Reference_Irradiance)*...
Temperature_factor;



% Avoid negative power
%In a cases with A PV CAN NOT generate negative power
%but we need to add this as a edge Case

Ppv=max(Ppv,0);


end