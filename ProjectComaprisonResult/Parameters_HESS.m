%% Parameters_HESS.m
% Objective 4: PV + Hybrid Energy Storage System (HESS)
% Battery + Supercapacitor + Flywheel
% Scaled for IEEE 14 Bus (MW range)
%
% NOTE: clc and clear have been deliberately removed
%       so this file can be called mid-script without
%       wiping existing workspace variables

%% Simulation Parameters
Simulation_Time = 24;       % hours
Time_Step       = 0.01;     % hours

%% PV System Parameters
PV_Rated_Power  = 15000000; % 15 MW
PV_Efficiency   = 0.20;
PV_Area         = 125;

%% Load Parameters
Load_Rated_Power  = 5000000; % 5 MW
Load_Power_Factor = 0.95;

%% Grid Parameters
Grid_Voltage    = 400;       % V (three phase)
Grid_Frequency  = 50;        % Hz

%% ── BATTERY Parameters ───────────────────────────────────────────
%Battery.Capacity              = 10000000; % 10 MWh
Battery.SOC_initial           = 0.80;     % 80% as fraction
Battery.SOC_max               = 0.95;     % 95% max
Battery.SOC_min               = 0.20;     % 20% min
%Battery.Max_charge_power      = 3000000;  % 3 MW
%Battery.Max_discharge_power   = 3000000;  % 3 MW
Battery.Charge_efficiency     = 0.95;
Battery.Discharge_efficiency  = 0.95;
Battery.Cycle_Life            = 3000;
Battery.Max_charge_power    = 50000000;  % 50 MW
Battery.Max_discharge_power = 50000000;  % 50 MW
Battery.Capacity   = 500000000; % 500 MWh
%% ── SUPERCAPACITOR Parameters ────────────────────────────────────
%SuperCap.Capacitance  = 500;     % Farads
SuperCap.Voltage_max  = 200;     % V maximum
SuperCap.Voltage_min  = 50;      % V minimum
SuperCap.Voltage_init = 150;     % V initial
%SuperCap.Max_Power    = 2000000; % 2 MW
SuperCap.Max_Power = 30000000;  % 30 MW
SuperCap.Capacitance = 5000;  

%% ── FLYWHEEL Parameters ──────────────────────────────────────────
%Flywheel.Inertia    = 500;       % kg.m^2
Flywheel.Speed_max  = 10000;     % RPM maximum
Flywheel.Speed_min  = 2000;      % RPM minimum
Flywheel.Speed_init = 6000;      % RPM initial
Flywheel.Loss       = 0.001;     % 0.1% mechanical loss per step
%Flywheel.Max_Power  = 1000000;   % 1 MW
Flywheel.Max_Power = 20000000;  % 20 MW
Flywheel.Inertia   = 5000; 