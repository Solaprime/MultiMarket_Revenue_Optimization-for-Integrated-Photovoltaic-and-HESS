%function [outputArg1,outputArg2] = Load_Model(inputArg1,inputArg2)
%LOAD_MODEL Summary of this function goes here
%   Detailed explanation goes here
%outputArg1 = inputArg1;
%outputArg2 = inputArg2;
%end

function Pload = Load_Model(time,Load)

%Create the Ouput Array
Pload=zeros(size(time));


for k=1:length(time)


    hour=time(k)/3600;

   %Between  6pm and 11pm we have Peak Load
    if hour>=18 && hour<=23


        % Evening peak

        Pload(k)=Load.Peak_Load;


        %For Day load, So daytime is Load
%Is Fixed at 3000W
    elseif hour>=7 && hour<18


        % Day load

        Pload(k)=Load.Day_Load;


    else


        % Night load 7am to 11pm

        Pload(k)=Load.Base_Load;


    end


end


end

