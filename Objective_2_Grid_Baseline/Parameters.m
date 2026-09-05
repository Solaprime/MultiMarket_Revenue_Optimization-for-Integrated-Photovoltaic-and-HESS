%% Parameters.m
% PV + Grid Baseline System Parameters

clear;
clc;


%% Simulation Parameters
%%New values are being computed after 60 seconds
Simulation.time_step = 60; 
% seconds

Simulation.hours = 24;

Simulation.time = 0:Simulation.time_step:...
    Simulation.hours*3600;


%% PV System Parameters

PV.Rated_Power = 5000;     
% 5kW PV system

PV.Area = 30;              
% m^2

PV.Efficiency = 0.20;


PV.Reference_Irradiance = 1000;
% W/m2


PV.Reference_Temperature = 25;
%This Tells uS pv EFFICENCY CHANGES WITH Temperature
%Hot Panels _> Lowe Efficency

PV.Temperature_Coefficient = 0.004;


%% Load Parameters

%Even at Minimum Demand the value is
Load.Base_Load = 1000;
% 1kW minimum load


Load.Day_Load = 3000;

Load.Peak_Load = 5000;
% 5kW peak demand




%% Grid Parameters
%Grid Limits
Grid.Maximum_Power = 10000;
% 10kW grid connection

