%function [outputArg1,outputArg2] = Solar_Profile(inputArg1,inputArg2)
%SOLAR_PROFILE Summary of this function goes here
%   Detailed explanation goes here
%outputArg1 = inputArg1;
%outputArg2 = inputArg2;
%end

%This Function takes in time and Compute 
%and returns Irradiance

function Irradiance = Solar_Profile(time)


%Create the Irradiance array
Irradiance=zeros(size(time));


for k=1:length(time)


    hour=time(k)/3600;


    % Sunrise 6am to 6pm

    if hour >=6 && hour <=18


        % Solar curve, We Since the Sun increases and Decrease gradually,
        % we use sine Wave to approximate this Daily Pattern
     %1000 W/m^2 is our standard Test Condition

        Irradiance(k)=1000*...
        sin(pi*(hour-6)/12);


    else

        Irradiance(k)=0;


    end


end


end
