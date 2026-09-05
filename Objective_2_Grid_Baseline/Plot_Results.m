%function [outputArg1,outputArg2] = Plot_Results(inputArg1,inputArg2)
%PLOT_RESULTS Summary of this function goes here
%   Detailed explanation goes here
%outputArg1 = inputArg1;
%outputArg2 = inputArg2;
%end

function Plot_Results(time,...
    Irradiance,...
    Ppv,...
    Pload,...
    Pgrid)


time_hour=time/3600;



figure

plot(time_hour,Irradiance)

xlabel('Time (Hour)')
ylabel('Irradiance (W/m^2)')

title('Solar Irradiance Profile')
%this adds grid to the plot
grid on



figure

plot(time_hour,Ppv)

xlabel('Time (Hour)')
ylabel('PV Power (W)')

title('PV Generation')

grid on



figure

plot(time_hour,Pload)

xlabel('Time (Hour)')
ylabel('Load Power (W)')

title('Load Demand')

grid on



figure

plot(time_hour,Pgrid)

xlabel('Time (Hour)')
ylabel('Grid Power (W)')

title('Grid Power Exchange')

grid on


end

