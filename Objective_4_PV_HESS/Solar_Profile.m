function Irradiance = Solar_Profile(time)

% Solar_Profile
% Generates solar irradiance profile


Irradiance = zeros(size(time));


for k = 1:length(time)

    current_time = time(k);


    % Morning
    if current_time >= 6 && current_time < 12
        
        Irradiance(k) = 600 + ...
        (current_time-6)*100;


    % Afternoon peak
    elseif current_time >= 12 && current_time < 16
        
        Irradiance(k) = 1000;


    % Evening
    elseif current_time >=16 && current_time <18
        
        Irradiance(k)=800;


    % Night
    else
        
        Irradiance(k)=0;

    end

end

end