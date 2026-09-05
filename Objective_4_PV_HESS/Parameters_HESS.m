%% Parameters_HESS.m
% Objective 4: PV + Hybrid Energy Storage System (HESS)
% Battery + Supercapacitor + Flywheel
% Scaled for IEEE 14 Bus (MW range)
clc;
clear;

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
% Battery handles slow long duration energy storage
Battery.Capacity              = 500000000; % 500 MWh
Battery.SOC_initial           = 0.80;     % 80% initial (as fraction)
Battery.SOC_max               = 0.95;     % 95% max
Battery.SOC_min               = 0.20;     % 20% min
Battery.Max_charge_power      = 50000000;  % 5 MW
Battery.Max_discharge_power   = 50000000;  % 5 MW
Battery.Charge_efficiency     = 0.95;
Battery.Discharge_efficiency  = 0.95;
Battery.Cycle_Life            = 3000;

%% ── SUPERCAPACITOR Parameters ────────────────────────────────────
% Supercapacitor handles fast short duration power bursts
SuperCap.Capacitance  = 5000;    % Farads — large bank
SuperCap.Voltage_max  = 200;    % V maximum voltage
SuperCap.Voltage_min  = 50;     % V minimum (below this unusable)
SuperCap.Voltage_init = 150;    % V initial voltage
SuperCap.Max_Power    = 30000000; % 30 MW max charge/discharge power

%% ── FLYWHEEL Parameters ──────────────────────────────────────────
% Flywheel handles medium term power smoothing
Flywheel.Inertia    = 5000;      % kg.m^2
Flywheel.Speed_max  = 10000;    % RPM maximum
Flywheel.Speed_min  = 2000;     % RPM minimum (below this unusable)
Flywheel.Speed_init = 6000;     % RPM initial speed
Flywheel.Loss       = 0.001;    % 0.1% mechanical loss per step
Flywheel.Max_Power  = 20000000;  % 20 MW max charge/discharge power

%% ── HESS Priority Order ──────────────────────────────────────────
% When PV surplus exists:
%   1. Supercapacitor charges first  (fastest response)
%   2. Flywheel charges second       (medium response)
%   3. Battery charges last          (slowest response)
%
% When PV deficit exists:
%   1. Supercapacitor discharges first
%   2. Flywheel discharges second
%   3. Battery discharges last
%   4. Grid imports if all storage depleted
