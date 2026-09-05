%% Parameters.m

clear;
clc;

%% Simulation Parameters

dt = 1;              % Time step (seconds) of simulation, Every Simulation advanced by 1 hr
simulation_time = 3600; % 1 hour

time = 0:dt:simulation_time;


%% Battery Parameters

Battery.Capacity = 10*3600;   
% Energy capacity in Joules
% 10kWh converted to Joules

Battery.SOC_initial = 0.5;

Battery.SOC_max = 0.95;

Battery.SOC_min = 0.20;

%IF pv Sends 1000j Batery Stores 950j
Battery.Charge_efficiency = 0.95;

%If Loads  need 950J Battery will send 1000
Battery.Discharge_efficiency = 0.95;

%If pv generated 8000 watt
%Even if the PV generates 8 kW of excess power, the battery can only accept 5 kW. The remaining 3 kW must be curtailed 
% or exported to the grid.
Battery.Max_charge_power = 5000;

%The battery cannot supply more than:
Battery.Max_discharge_power = 5000;



%% Supercapacitor Parameters
 % Energy = 0.5 CV^2
SuperCap.Capacitance = 500;    % Farads

%Current Simulation start with 48v inital 
SuperCap.Voltage_initial = 48;

%the Maximum Voltage,maximum safe Voltage
SuperCap.Voltage_max = 48;

%Minimum Voltage, the Supercapictor 
SuperCap.Voltage_min = 20;

%Internal Resistance of SuperCapacitor
SuperCap.ESR = 0.01;



%% Flywheel Parameters

%Fly Wheeel Momen of Inertail, this Means
%Larger Inertail Means more stored Energy, 
%but Slower Acccelearation and Deceleration
Flywheel.Inertia = 10;   % kg.m2

%Initial Speed of the FlyWheel
Flywheel.Speed_initial = 5000; % rpm

%Mas Speed of FlyWheel
Flywheel.Speed_max = 10000;


Flywheel.Speed_min = 1000;

%Loss in FlywWheel
Flywheel.Loss = 0.01;
