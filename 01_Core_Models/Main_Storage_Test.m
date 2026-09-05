clear;
clc;


Parameters;



%% Initial Conditions


SOC = Battery.SOC_initial;

Voltage = SuperCap.Voltage_initial;

Speed = Flywheel.Speed_initial;



for k=1:length(time)



    % Test charging power

    P = 3000;



    %% Battery

    [SOC,Energy,DOD] = ...
        Battery_Model(P,...
        SOC,...
        dt,...
        Battery);


    SOC_result(k)=SOC;



    %% Supercapacitor


    [Voltage,SC_Energy]=...
        Supercapacitor_Model...
        (P,...
        Voltage,...
        dt,...
        SuperCap);


    Voltage_result(k)=Voltage;



    %% Flywheel


    [Speed,FW_Energy]=...
        Flywheel_Model...
        (P,...
        Speed,...
        dt,...
        Flywheel);


    Speed_result(k)=Speed;



end



%% Plot Results


figure

plot(time,SOC_result)

xlabel("Time (s)")
ylabel("SOC")

title("Battery SOC")

grid on



figure

plot(time,Voltage_result)

xlabel("Time (s)")
ylabel("Voltage (V)")

title("Supercapacitor Voltage")

grid on



figure

plot(time,Speed_result)

xlabel("Time (s)")
ylabel("RPM")

title("Flywheel Speed")

grid on
