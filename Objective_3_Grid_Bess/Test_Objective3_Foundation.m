clc;
clear;


Parameters_BESS


time = 0:0.01:24;


Irradiance = Solar_Profile(time);


PV = PV_Model(Irradiance,PV_Rated_Power);


Load = Load_Model(time,Load_Rated_Power);



figure

plot(time,Irradiance)

xlabel("Time (Hours)")
ylabel("Irradiance W/m2")
title("Solar Irradiance Profile")


figure

plot(time,PV)

xlabel("Time (Hours)")
ylabel("Power (W)")
title("PV Power Output")


figure

plot(time,Load)

xlabel("Time (Hours)")
ylabel("Power (W)")
title("Load Demand")


Battery_Power = Battery_Model(...
    PV,...
    Load,...
    Battery_Max_Charge_Power,...
    Battery_Max_Discharge_Power);



SOC = SOC_Model(...
    Battery_Power,...
    Battery_SOC_Initial,...
    Battery_Capacity,...
    Battery_Charge_Efficiency,...
    Time_Step);


figure

plot(time,Battery_Power)

xlabel("Time (Hours)")
ylabel("Battery Power (W)")
title("Battery Charging and Discharging")


grid on


figure

plot(time,SOC)

xlabel("Time (Hours)")
ylabel("SOC (%)")
title("Battery State of Charge")

grid on

%% Energy Management System


[Battery_Command, Grid_Command] = Energy_Management(...
    PV,...
    Load,...
    SOC,...
    Battery_SOC_Max,...
    Battery_SOC_Min,...
    Battery_Max_Charge_Power,...
    Battery_Max_Discharge_Power);



%% Plot Battery Command

figure

plot(time,Battery_Command)

xlabel("Time (Hours)")
ylabel("Battery Power (W)")
title("Battery EMS Command")

grid on



%% Plot Grid Power Exchange

figure

plot(time,Grid_Command)

xlabel("Time (Hours)")
ylabel("Grid Power (W)")
title("Grid Power Exchange")

grid on


%% Energy Balance Verification


Power_Error = PV + Grid_Command + Battery_Command - Load;


figure

plot(time,Power_Error)

xlabel("Time (Hours)")
ylabel("Power Error (W)")
title("Energy Balance Verification")

grid on


disp("Maximum Energy Balance Error:")
disp(max(abs(Power_Error)))

%% Objective 3 Performance Analysis


% Convert power values to energy (kWh)

PV_Energy = trapz(time,PV)/1000;


Load_Energy = trapz(time,Load)/1000;


Battery_Charge_Energy = ...
    trapz(time,max(Battery_Command,0))/1000;


Battery_Discharge_Energy = ...
    abs(trapz(time,min(Battery_Command,0)))/1000;


Grid_Import_Energy = ...
    trapz(time,max(Grid_Command,0))/1000;


Grid_Export_Energy = ...
    abs(trapz(time,min(Grid_Command,0)))/1000;



%% Renewable Contribution

Renewable_Energy_Supplied = ...
    PV_Energy - Grid_Export_Energy;


Renewable_Percentage = ...
    (Renewable_Energy_Supplied / Load_Energy)*100;



%% Grid Dependency

Grid_Dependency = ...
    (Grid_Import_Energy / Load_Energy)*100;



%% Display Results


disp("========== Objective 3 Performance Results ==========")


disp("Total PV Energy Generated (kWh):")
disp(PV_Energy)


disp("Total Load Energy Demand (kWh):")
disp(Load_Energy)


disp("Battery Charging Energy (kWh):")
disp(Battery_Charge_Energy)


disp("Battery Discharging Energy (kWh):")
disp(Battery_Discharge_Energy)


disp("Grid Import Energy (kWh):")
disp(Grid_Import_Energy)


disp("Grid Export Energy (kWh):")
disp(Grid_Export_Energy)


disp("Renewable Contribution (%):")
disp(Renewable_Percentage)


disp("Grid Dependency (%):")
disp(Grid_Dependency)

%% PV Self Consumption Ratio

Self_Consumption_Ratio = ...
    ((PV_Energy - Grid_Export_Energy) / PV_Energy)*100;


disp("PV Self Consumption Ratio (%):")
disp(Self_Consumption_Ratio)