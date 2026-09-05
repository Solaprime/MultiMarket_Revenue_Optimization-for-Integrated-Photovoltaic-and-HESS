clear;
clc;
close all;


%% Load Parameters

%Executes Everything in Parameters.m

Parameters;



%% Generate Solar Irradiance

Irradiance = Solar_Profile...
    (Simulation.time);



%% PV Temperature

Temperature = 25;


%% PV Generation

Ppv = PV_Model...
    (Irradiance,...
    Temperature,...
    PV);



%% Generate Load

Pload = Load_Model...
    (Simulation.time,...
    Load);



%% Grid Interaction

[Pgrid,Export,Import]=...
    Grid_Model...
    (Ppv,Pload);



%% Energy Calculation


PV_Energy = sum(Ppv)*...
    Simulation.time_step/3600;


Load_Energy=sum(Pload)*...
    Simulation.time_step/3600;


Grid_Energy=sum(Import)*...
    Simulation.time_step/3600;



fprintf("\nPV Energy = %.2f kWh\n",PV_Energy/1000)

fprintf("Load Energy = %.2f kWh\n",Load_Energy/1000)

fprintf("Grid Import = %.2f kWh\n",Grid_Energy/1000)



%% Plot Results

Plot_Results...
(Simulation.time,...
Irradiance,...
Ppv,...
Pload,...
Pgrid);
