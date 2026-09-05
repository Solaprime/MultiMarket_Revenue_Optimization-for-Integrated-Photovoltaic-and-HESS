%% Generate irradiance data
time = (0:60:86400)';
irradiance = zeros(size(time));

for k = 1:length(time)
    hour = time(k)/3600;
    if hour >= 6 && hour <= 18
        irradiance(k) = 1000 * sin(pi*(hour-6)/12);
    else
        irradiance(k) = 0;
    end
end

solar_data.time = time;
solar_data.signals.values = irradiance;
solar_data.signals.dimensions = 1;

assignin('base', 'solar_data', solar_data);
disp('solar_data loaded successfully!');