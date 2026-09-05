function Load_Power = Load_Model(time, Rated_Load)

% Load_Model
% Creates a daily residential load profile


Load_Power = zeros(size(time));


for k = 1:length(time)

    t = time(k);


    % 00:00 - 06:00 (Night load)
    if t >= 0 && t < 6

        Load_Power(k) = 0.6 * Rated_Load;


    % 06:00 - 09:00 (Morning peak)
    elseif t >= 6 && t < 9

        Load_Power(k) = 1.2 * Rated_Load;


    % 09:00 - 17:00 (Daytime)
    elseif t >= 9 && t < 17

        Load_Power(k) = Rated_Load;


    % 17:00 - 22:00 (Evening peak)
    elseif t >= 17 && t < 22

        Load_Power(k) = 1.6 * Rated_Load;


    % 22:00 - 24:00 (Late night)
    else

        Load_Power(k) = 0.8 * Rated_Load;

    end

end

end