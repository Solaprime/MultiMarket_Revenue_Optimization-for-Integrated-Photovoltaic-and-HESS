%function [outputArg1,outputArg2] = Grid_Model(inputArg1,inputArg2)
%GRID_MODEL Summary of this function goes here
%   Detailed explanation goes here
%outputArg1 = inputArg1;
%outputArg2 = inputArg2;
%end

function [Pgrid,Export,Import]=...
    Grid_Model(Ppv,Pload)


% Power balance

Pgrid=Pload-Ppv;



% Grid import

Import=max(Pgrid,0);



% Grid export

Export=max(-Pgrid,0);



end