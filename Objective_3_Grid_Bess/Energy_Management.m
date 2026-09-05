function [Battery_Command, Grid_Command] = Energy_Management(...
    PV_Power,...
    Load_Power,...
    SOC,...
    SOC_Max,...
    SOC_Min,...
    Max_Charge,...
    Max_Discharge)

% Energy Management Controller
% Objective 3 PV + Battery + Grid System



Battery_Command = zeros(size(PV_Power));

Grid_Command = zeros(size(PV_Power));


for k = 1:length(PV_Power)


    % Calculate power difference
%Calculate Excess power the Differnce between PV_Power and Load Power
    Power_Error = PV_Power(k) - Load_Power(k);



    % Excess PV available
    % Charge Battery

    if Power_Error > 0

    %%Check SOC of the BATTERY
        if SOC(k) < SOC_Max

           %The battery will absorb the Minimum between the 
           %Power Error and The Max_Charge
            Battery_Command(k) = min(...
                Power_Error,...
                Max_Charge);


        else

            Battery_Command(k)=0;


        end



    % PV is not enough
    % Discharge Battery

    elseif Power_Error < 0

        %If soc us greater than the Soc We set as the Minimum Soc
        if SOC(k) > SOC_Min


            Battery_Command(k)=max(...
                Power_Error,...
                -Max_Discharge);


        else

            Battery_Command(k)=0;


        end


    end



    % Grid supplies remaining power

    Grid_Command(k)=...
        Load_Power(k) - ...
        PV_Power(k) - ...
        Battery_Command(k);



end


end