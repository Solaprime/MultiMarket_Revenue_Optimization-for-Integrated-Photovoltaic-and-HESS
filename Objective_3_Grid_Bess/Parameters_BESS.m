%% Parameters_BESS.m
% Objective 3: PV + Battery Energy Storage System
% System Parameters
clc;
clear;

%% Simulation Parameters
Simulation_Time = 24;      % Simulation duration (hours)
Time_Step = 0.01;          % Time resolution (hours)

%% PV System Parameters
PV_Rated_Power = 15000000;    % ← CHANGED: 25000 W → 15,000,000 W (15 MW)
                               %   Scaled up to match IEEE 14 Bus MW range
PV_Efficiency = 0.20;         % PV efficiency (unchanged)
PV_Area = 125;                % PV panel area m^2 (unchanged)

%% Load Parameters
Load_Rated_Power = 5000000;   % ← CHANGED: 5000 W → 5,000,000 W (5 MW)
                               %   Scaled up to match IEEE 14 Bus MW range
Load_Power_Factor = 0.95;     % (unchanged)

%% Grid Parameters
Grid_Voltage = 400;           % Three phase voltage V (unchanged)
Grid_Frequency = 50;          % Hz (unchanged)

%% Battery Parameters
Battery_Capacity = 10000000;  % ← CHANGED: 20000 Wh → 10,000,000 Wh (10 MWh)
                               %   Scaled to store meaningful MW-scale energy
Battery_SOC_Initial = 80;     % Initial SOC % (unchanged)
Battery_SOC_Max = 100;        % ← KEPT: already correct
Battery_SOC_Min = 20;         % ← KEPT: already correct
Battery_Max_Charge_Power = 5000000;    % ← CHANGED: 10000 W → 5,000,000 W (5 MW)
Battery_Max_Discharge_Power = 5000000; % ← CHANGED: 10000 W → 5,000,000 W (5 MW)
                                        %   Scaled to match new battery size
Battery_Charge_Efficiency = 0.95;      % (unchanged)
Battery_Discharge_Efficiency = 0.95;   % (unchanged)

%% Battery Degradation Parameters
Battery_Cycle_Life = 3000;      % (unchanged)
Battery_Initial_Capacity = 100; % (unchanged)

%% Controller Parameters
SOC_Target = 50;               % (unchanged)