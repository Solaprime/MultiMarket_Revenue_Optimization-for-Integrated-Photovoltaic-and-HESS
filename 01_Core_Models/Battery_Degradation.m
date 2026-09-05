%function [outputArg1,outputArg2] = Battery_Degradation(inputArg1,inputArg2)
%BATTERY_DEGRADATION Summary of this function goes here
%   Detailed explanation goes here
%outputArg1 = inputArg1;
%outputArg2 = inputArg2;
%end

function NewCapacity = Battery_Degradation...
    (Capacity,Cycles)


degradation_rate = 0.00005;


NewCapacity = Capacity * ...
    (1-degradation_rate*Cycles);


end

