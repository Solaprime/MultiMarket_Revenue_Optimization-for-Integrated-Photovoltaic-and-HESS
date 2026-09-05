%% IEEE14_PV_Injection.m
% Objective 3: PV + BESS injected into IEEE 14 Bus Grid
% Connects existing Solar_Profile, PV_Model, Battery_Model,
% SOC_Model and Energy_Management to the IEEE 14 Bus network
% Runs OPF for 24 hours and captures all generator activities
%
% Required files (already built):
%   Solar_Profile.m
%   PV_Model.m
%   Load_Model.m
%   Battery_Model.m
%   SOC_Model.m
%   Energy_Management.m
%   Parameters_BESS.m
%
% Required toolbox:
%   MATPOWER (already installed)

clc;
clear;

%% ── STEP 1: Load Parameters ──────────────────────────────────────
Parameters_BESS;   % Loads all your existing system parameters

%% ── STEP 2: Load IEEE 14 Bus Network ────────────────────────────
mpc = case14;      % Load standard IEEE 14 Bus test case

% Base power for converting MW to per unit
baseMVA = mpc.baseMVA;   % = 100 MVA

fprintf('IEEE 14 Bus network loaded successfully\n');
fprintf('Base MVA: %d\n', baseMVA);
fprintf('Number of buses: %d\n', size(mpc.bus,1));
fprintf('Number of generators: %d\n', size(mpc.gen,1));
fprintf('Number of branches: %d\n\n', size(mpc.branch,1));

%% ── STEP 3: Define PV Injection Bus ─────────────────────────────
PV_Bus = 2;        % Bus 2 chosen for PV injection
                   % Has 140 MW generator — PV will reduce its output

fprintf('PV will be injected at Bus %d\n', PV_Bus);
fprintf('Existing load at Bus %d: %.1f MW\n\n', ...
    PV_Bus, mpc.bus(PV_Bus,3));

%% ── STEP 4: Generate 24 Hour Time Vector ─────────────────────────
time = 0:Time_Step:24;     % Uses Time_Step from Parameters_BESS
num_steps = length(time);

%% ── STEP 5: Generate PV and Load Profiles ────────────────────────
Irradiance  = Solar_Profile(time);
PV_Power_W  = PV_Model(Irradiance, PV_Rated_Power);
Load_Power_W = Load_Model(time, Load_Rated_Power);

% Convert Watts to MW for MATPOWER
PV_Power_MW   = PV_Power_W   / 1e6;
Load_Power_MW = Load_Power_W / 1e6;

fprintf('Peak PV Power: %.2f MW\n',   max(PV_Power_MW));
fprintf('Peak Load Power: %.2f MW\n\n', max(Load_Power_MW));

%% ── STEP 6: Run Battery Model ────────────────────────────────────
Battery_Power_W = Battery_Model(...
    PV_Power_W, ...
    Load_Power_W, ...
    Battery_Max_Charge_Power, ...
    Battery_Max_Discharge_Power);

SOC = SOC_Model(...
    Battery_Power_W, ...
    Battery_SOC_Initial, ...
    Battery_Capacity, ...
    Battery_Charge_Efficiency, ...
    Time_Step);

[Battery_Command_W, ~] = Energy_Management(...
    PV_Power_W, ...
    Load_Power_W, ...
    SOC, ...
    Battery_SOC_Max, ...
    Battery_SOC_Min, ...
    Battery_Max_Charge_Power, ...
    Battery_Max_Discharge_Power);

Battery_Command_MW = Battery_Command_W / 1e6;

%% ── STEP 7: Run 24 Hour OPF on IEEE 14 Bus ───────────────────────
% Pre-allocate storage for all generator outputs over 24 hours
num_gen     = size(mpc.gen, 1);
Gen_Output  = zeros(num_steps, num_gen);   % All generator MW outputs
Bus2_Gen    = zeros(num_steps, 1);         % Bus 2 generator specifically
PV_Injected = zeros(num_steps, 1);         % Actual PV injected each step
Grid_Import = zeros(num_steps, 1);         % Grid import at Bus 2
OPF_Success = zeros(num_steps, 1);         % Track convergence

fprintf('Running 24-hour OPF simulation...\n');
fprintf('This may take a few minutes.\n\n');

for k = 1:num_steps

    % Copy base network for this time step
    mpc_k = mpc;

    % Net PV contribution at Bus 2 (PV minus battery charging)
    Net_PV_MW = PV_Power_MW(k) - Battery_Command_MW(k);
    Net_PV_MW = max(Net_PV_MW, 0);   % Cannot be negative

    % Inject PV at Bus 2 by reducing generator output requirement
    % Find which generator is at Bus 2
    gen_idx = find(mpc_k.gen(:,1) == PV_Bus);

    % Reduce Bus 2 generator minimum output by PV amount
    original_Pmin = mpc_k.gen(gen_idx, 10);
    original_Pmax = mpc_k.gen(gen_idx, 9);

    % PV reduces how much the generator needs to produce
    new_Pmax = max(original_Pmax - Net_PV_MW, 0);
    mpc_k.gen(gen_idx, 9)  = new_Pmax;
    mpc_k.gen(gen_idx, 10) = min(original_Pmin, new_Pmax);

    % Run Optimal Power Flow — as specified by lecturer (Pointer 3)
    mpopt = mpoption('verbose', 0, 'out.all', 0);
    results_k = runopf(mpc_k, mpopt);

    % Store results if converged
    if results_k.success
        Gen_Output(k,:) = results_k.gen(:,2)';   % All generator MW
        Bus2_Gen(k)     = results_k.gen(gen_idx, 2);
        PV_Injected(k)  = Net_PV_MW;
        Grid_Import(k)  = max(-results_k.gen(1,2), 0);
        OPF_Success(k)  = 1;
    else
        % If not converged keep previous step values
        if k > 1
            Gen_Output(k,:) = Gen_Output(k-1,:);
            Bus2_Gen(k)     = Bus2_Gen(k-1);
        end
        fprintf('Warning: Step %d did not converge\n', k);
    end

    % Progress update every 500 steps
    if mod(k, 500) == 0
        fprintf('Progress: Hour %.1f / 24\n', time(k));
    end

end

fprintf('\nSimulation complete!\n');
fprintf('Convergence rate: %.1f%%\n\n', ...
    (sum(OPF_Success)/num_steps)*100);

%% ── STEP 8: Calculate Performance Metrics ────────────────────────
% Energy calculations using trapezoidal integration
PV_Energy_kWh      = trapz(time, PV_Power_W)   / 1000;
Load_Energy_kWh    = trapz(time, Load_Power_W) / 1000;
Battery_Charge_kWh = trapz(time, max(Battery_Command_W,0)) / 1000;
Battery_Disch_kWh  = abs(trapz(time, min(Battery_Command_W,0))) / 1000;

% Generator reduction due to PV
Gen2_Baseline_MWh = trapz(time, ones(size(time)) .* 40);
Gen2_Actual_MWh   = trapz(time, Bus2_Gen);
Gen2_Reduction    = Gen2_Baseline_MWh - Gen2_Actual_MWh;

% Renewable contribution
Renewable_Pct = (PV_Energy_kWh / Load_Energy_kWh) * 100;

%% ── STEP 9: Display Results ──────────────────────────────────────
fprintf('========== IEEE 14 Bus PV + BESS Results ==========\n\n');
fprintf('PV Energy Generated:        %.2f kWh\n',  PV_Energy_kWh);
fprintf('Total Load Energy:          %.2f kWh\n',  Load_Energy_kWh);
fprintf('Battery Charged:            %.2f kWh\n',  Battery_Charge_kWh);
fprintf('Battery Discharged:         %.2f kWh\n',  Battery_Disch_kWh);
fprintf('Renewable Contribution:     %.1f %%\n',   Renewable_Pct);
fprintf('Bus 2 Generator Reduction:  %.2f MWh\n',  Gen2_Reduction);
fprintf('\n');

%% ── STEP 10: Plot All Results ────────────────────────────────────

% Plot 1: Solar Irradiance
figure('Name', 'Solar Irradiance Profile');
plot(time, Irradiance, 'Color', [0.9 0.6 0.1], 'LineWidth', 2);
xlabel('Time (Hours)');
ylabel('Irradiance (W/m^2)');
title('Solar Irradiance Profile — 24 Hours');
grid on;
xlim([0 24]);
xticks(0:2:24);

% Plot 2: PV Power Output
figure('Name', 'PV Power Output');
plot(time, PV_Power_W/1000, 'Color', [0.2 0.7 0.3], 'LineWidth', 2);
xlabel('Time (Hours)');
ylabel('Power (kW)');
title('PV Power Output — Bus 2');
grid on;
xlim([0 24]);
xticks(0:2:24);

% Plot 3: All Generator Outputs over 24 Hours
figure('Name', 'All Generator Outputs — IEEE 14 Bus');
gen_colors = {'b','r','g','m','c'};
gen_labels = {'Gen 1 (Bus 1)', 'Gen 2 (Bus 2)', ...
              'Gen 3 (Bus 3)', 'Gen 4 (Bus 6)', ...
              'Gen 5 (Bus 8)'};
hold on;
for g = 1:num_gen
    plot(time, Gen_Output(:,g), ...
        'Color', gen_colors{g}, ...
        'LineWidth', 1.5, ...
        'DisplayName', gen_labels{g});
end
hold off;
xlabel('Time (Hours)');
ylabel('Generator Output (MW)');
title('All Generator Outputs — 24 Hour Simulation');
legend('Location', 'best');
grid on;
xlim([0 24]);
xticks(0:2:24);

% Plot 4: Bus 2 Generator vs PV Injection
figure('Name', 'Bus 2 — Generator vs PV');
hold on;
plot(time, Bus2_Gen, 'b-', 'LineWidth', 2, ...
    'DisplayName', 'Bus 2 Generator (MW)');
plot(time, PV_Injected, 'g-', 'LineWidth', 2, ...
    'DisplayName', 'PV Injected (MW)');
hold off;
xlabel('Time (Hours)');
ylabel('Power (MW)');
title('Bus 2 — Generator Output vs PV Injection');
legend('Location', 'best');
grid on;
xlim([0 24]);
xticks(0:2:24);

% Plot 5: Battery SOC
figure('Name', 'Battery State of Charge');
plot(time, SOC, 'Color', [0.8 0.2 0.2], 'LineWidth', 2);
xlabel('Time (Hours)');
ylabel('SOC (%)');
title('Battery State of Charge — 24 Hours');
ylim([0 100]);
grid on;
xlim([0 24]);
xticks(0:2:24);

% Plot 6: Power Balance Summary
figure('Name', 'Power Balance');
hold on;
plot(time, PV_Power_W/1000,       'g-',  'LineWidth', 2, ...
    'DisplayName', 'PV Power (kW)');
plot(time, Load_Power_W/1000,     'r-',  'LineWidth', 2, ...
    'DisplayName', 'Load (kW)');
plot(time, Battery_Command_W/1000,'b--', 'LineWidth', 1.5, ...
    'DisplayName', 'Battery (kW)');
hold off;
xlabel('Time (Hours)');
ylabel('Power (kW)');
title('Power Balance — PV + BESS + Grid');
legend('Location', 'best');
grid on;
xlim([0 24]);
xticks(0:2:24);

fprintf('All plots generated successfully!\n');
fprintf('Objective 3 complete.\n');