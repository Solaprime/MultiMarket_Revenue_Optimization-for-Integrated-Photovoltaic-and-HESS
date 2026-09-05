%% OBJECTIVE 2
% PV + GRID BASELINE MODEL
% MATLAB R2024b Compatible

clear;
clc;
close all;


model = 'Objective2_PV_Grid_Baseline';


%% Load SPS Library

load_system('sps_lib');


%% Create Model

if bdIsLoaded(model)
    close_system(model,0);
end

new_system(model);
open_system(model);



%% Find Required Blocks

powergui = find_system('sps_lib',...
    'SearchDepth',10,...
    'Name','powergui');


pv = find_system('sps_lib',...
    'SearchDepth',10,...
    'Name','PV Array');


bridge = find_system('sps_lib',...
    'SearchDepth',10,...
    'Name','Universal Bridge');


grid = find_system('sps_lib',...
    'SearchDepth',10,...
    'Name','Three-Phase Source');


loadblock = find_system('sps_lib',...
    'SearchDepth',10,...
    'Name','Three-Phase Parallel RLC Load');


%%New matlab Version does not have Capacitor, So we use Series RLC branch
%To Simulate Capacitor

%capacitor = find_system('sps_lib',...
%    'SearchDepth',10,...
%    'Name','Capacitor');

capacitor = find_system('sps_lib',...
    'SearchDepth',10,...
    'Name','Series RLC Branch');



%% Check Blocks

if isempty(pv)
    error("PV Array block not found")
end

if isempty(capacitor)
     error("Series RLC Branch block not found")
end


%% Add Blocks


add_block(powergui{1},...
    [model '/powergui'],...
    'Position',[50 50 120 90]);



% PV

add_block(pv{1},...
    [model '/PV_Array'],...
    'Position',[150 180 280 300]);



% DC Capacitor

add_block(capacitor{1},...
    [model '/DC_Link_Capacitor'],...
    'Position',[350 180 430 300]);



% Inverter

add_block(bridge{1},...
    [model '/Universal_Bridge_Inverter'],...
    'Position',[520 160 680 320]);



% Grid

add_block(grid{1},...
    [model '/Grid'],...
    'Position',[850 100 1000 200]);



% Load

add_block(loadblock{1},...
    [model '/Load'],...
    'Position',[850 300 1000 400]);



%% Add Irradiance Source

add_block('simulink/Sources/From Workspace',...
    [model '/Solar_Irradiance'],...
    'Position',[120 50 260 100]);


%% Create Irradiance Data

time = (0:60:86400)';


irradiance = zeros(size(time));


for k=1:length(time)

    hour=time(k)/3600;

    if hour>=6 && hour<=18
        
        irradiance(k)=1000*sin(pi*(hour-6)/12);

    else

        irradiance(k)=0;

    end

end



solar_data.time=time;

solar_data.signals.values=irradiance;

solar_data.signals.dimensions=1;



assignin('base',...
    'solar_data',...
    solar_data);



set_param([model '/Solar_Irradiance'],...
    'VariableName',...
    'solar_data');



%% Add Scopes

add_block('simulink/Sinks/Scope',...
    [model '/PV_Power_Scope'],...
    'Position',[1100 150 1200 250]);



%% Simulation

set_param(model,...
    'StopTime','86400');


save_system(model);


disp('================================')
disp('OBJECTIVE 2 MODEL GENERATED')
disp('PV + DC LINK + GRID + IRRADIANCE')
disp('================================')
