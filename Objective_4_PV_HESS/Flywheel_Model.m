%function [outputArg1,outputArg2] = Flywheel_Model(inputArg1,inputArg2)
%FLYWHEEL_MODEL Summary of this function goes here
%   Detailed explanation goes here
%outputArg1 = inputArg1;
%outputArg2 = inputArg2;
%end

%How much energy is now stored in the flywheel?
function [Speed_new,Energy_new]=...
    Flywheel_Model(P,Speed_old,dt,Flywheel)


%Inertial of flyWheel
J = Flywheel.Inertia;



% Convert rpm to rad/s

%ω=RPM×2π/20​
omega_old = Speed_old*2*pi/60;



% Existing Energy
% 0.5 j w^2
Energy_old = 0.5*J*omega_old^2;



% Add power

Energy_new = Energy_old + P*dt;



% Mechanical loss

%Account for Loss
Energy_new = Energy_new*(1-Flywheel.Loss);



% Calculate speed

omega_new=sqrt((2*Energy_new)/J);



Speed_new=omega_new*60/(2*pi);



% Speed constraints


Speed_new=max(min(Speed_new,...
    Flywheel.Speed_max),...
    Flywheel.Speed_min);



end

