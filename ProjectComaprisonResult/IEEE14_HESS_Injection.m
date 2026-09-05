%% IEEE14_HESS_Injection.m
% Objective 4: PV + HESS injected into IEEE 14 Bus Grid
% HESS = Battery + Supercapacitor + Flywheel
%
% Reuses existing functions:
%   Solar_Profile.m
%   PV_Model.m
%   Load_Model.m
%   Battery_Model.m        (from Objective 1)
%   Supercapacitor_Model.m (from Objective 1)
%   Flywheel_Model.m       (from Objective 1)
%   HESS_EMS.m             (new)
%   Parameters_HESS.m      (new)

clc;
clear;

%% ── STEP 1: Load Parameters ──────────────────────────────────────
Parameters_HESS;

fprintf('========== Objective 4: PV + HESS ==========\n\n');

%% ── STEP 2: Load IEEE 14 Bus ─────────────────────────────────────
mpc = case14;
baseMVA = mpc.baseMVA;

fprintf('IEEE 14 Bus loaded successfully\n');
fprintf('Generators: %d | Buses: %d | Branches: %d\n\n', ...
    size(mpc.gen,1), size(mpc.bus,1), size(mpc.branch,1));

%% ── STEP 3: PV Injection Bus ─────────────────────────────────────
PV_Bus  = 2;
gen_idx = find(mpc.gen(:,1) == PV_Bus);

fprintf('PV + HESS injected at Bus %d\n\n', PV_Bus);

%% ── STEP 4: Time Vector and Profiles ────────────────────────────
time      = 0:Time_Step:24;
num_steps = length(time);

Irradiance   = Solar_Profile(time);
PV_Power_W   = PV_Model(Irradiance, PV_Rated_Power);
Load_Power_W = Load_Model(time, Load_Rated_Power);

PV_Power_MW   = PV_Power_W   / 1e6;
Load_Power_MW = Load_Power_W / 1e6;

fprintf('Peak PV Power:   %.2f MW\n', max(PV_Power_MW));
fprintf('Peak Load Power: %.2f MW\n\n', max(Load_Power_MW));

%% ── STEP 5: Initialise Storage States ───────────────────────────
% Battery
SOC_bat  = zeros(num_steps, 1);
SOC_bat(1) = Battery.SOC_initial;

% Supercapacitor
V_sc     = zeros(num_steps, 1);
V_sc(1)  = SuperCap.Voltage_init;
E_sc     = zeros(num_steps, 1);
E_sc(1)  = 0.5 * SuperCap.Capacitance * SuperCap.Voltage_init^2;

% Flywheel
Speed_fw = zeros(num_steps, 1);
Speed_fw(1) = Flywheel.Speed_init;
E_fw     = zeros(num_steps, 1);
omega_init = Flywheel.Speed_init * 2 * pi / 60;
E_fw(1)  = 0.5 * Flywheel.Inertia * omega_init^2;

%% ── STEP 6: Storage Power Commands ──────────────────────────────
P_bat_cmd  = zeros(num_steps, 1);
P_sc_cmd   = zeros(num_steps, 1);
P_fw_cmd   = zeros(num_steps, 1);
P_grid_cmd = zeros(num_steps, 1);

%% ── STEP 7: Run 24 Hour HESS Simulation ─────────────────────────
% Also track all IEEE 14 Bus generator outputs
num_gen    = size(mpc.gen, 1);
Gen_Output = zeros(num_steps, num_gen);
Bus2_Gen   = zeros(num_steps, 1);
OPF_Success = zeros(num_steps, 1);

fprintf('Running 24-hour HESS simulation...\n\n');

for k = 1:num_steps

    %% Power error at this step
    Power_Error = PV_Power_W(k) - Load_Power_W(k);

    %% Run HESS EMS — get power commands
    [P_bat_cmd(k), P_sc_cmd(k), P_fw_cmd(k), P_grid_cmd(k)] = ...
        HESS_EMS(...
            Power_Error, ...
            SOC_bat(k), ...
            V_sc(k), ...
            Speed_fw(k), ...
            Battery, ...
            SuperCap, ...
            Flywheel);

    %% Update Battery state
    if k < num_steps
        [SOC_bat(k+1), ~, ~] = Battery_Model(...
            P_bat_cmd(k), ...
            SOC_bat(k), ...
            Time_Step, ...
            Battery);
    end

    %% Update Supercapacitor state
    if k < num_steps
        [V_sc(k+1), E_sc(k+1)] = Supercapacitor_Model(...
            P_sc_cmd(k), ...
            V_sc(k), ...
            Time_Step, ...
            SuperCap);
    end

    %% Update Flywheel state
    if k < num_steps
        [Speed_fw(k+1), E_fw(k+1)] = Flywheel_Model(...
            P_fw_cmd(k), ...
            Speed_fw(k), ...
            Time_Step, ...
            Flywheel);
    end

    %% Run IEEE 14 Bus Power Flow
    mpc_k = mpc;

    % Net PV after HESS (convert to MW)
    Net_PV_MW = (PV_Power_W(k) - P_bat_cmd(k) - ...
                 P_sc_cmd(k) - P_fw_cmd(k)) / 1e6;
    Net_PV_MW = max(Net_PV_MW, 0);

    % Reduce Bus 2 generator requirement by PV amount
    new_Pmax = max(mpc_k.gen(gen_idx,9) - Net_PV_MW, 0);
    mpc_k.gen(gen_idx, 9)  = new_Pmax;
    mpc_k.gen(gen_idx, 10) = min(mpc_k.gen(gen_idx,10), new_Pmax);

    % Run Optimal Power Flow — as specified by lecturer (Pointer 3)
    mpopt     = mpoption('verbose', 0, 'out.all', 0);
    results_k = runopf(mpc_k, mpopt);

    if results_k.success
        Gen_Output(k,:) = results_k.gen(:,2)';
        Bus2_Gen(k)     = results_k.gen(gen_idx, 2);
        OPF_Success(k)  = 1;
    else
        if k > 1
            Gen_Output(k,:) = Gen_Output(k-1,:);
            Bus2_Gen(k)     = Bus2_Gen(k-1);
        end
    end

    %% Progress update
    if mod(k, 500) == 0
        fprintf('Progress: Hour %.1f / 24\n', time(k));
    end

end

fprintf('\nSimulation complete!\n');
fprintf('Convergence rate: %.1f%%\n\n', ...
    (sum(OPF_Success)/num_steps)*100);

%% ── STEP 8: Performance Metrics ─────────────────────────────────
PV_Energy_kWh   = trapz(time, PV_Power_W)   / 1000;
Load_Energy_kWh = trapz(time, Load_Power_W) / 1000;

Bat_Charge_kWh  = trapz(time, max(P_bat_cmd,0))  / 1000;
Bat_Disch_kWh   = abs(trapz(time, min(P_bat_cmd,0))) / 1000;

SC_Charge_kWh   = trapz(time, max(P_sc_cmd,0))   / 1000;
SC_Disch_kWh    = abs(trapz(time, min(P_sc_cmd,0)))  / 1000;

FW_Charge_kWh   = trapz(time, max(P_fw_cmd,0))   / 1000;
FW_Disch_kWh    = abs(trapz(time, min(P_fw_cmd,0)))  / 1000;

Grid_Import_kWh = trapz(time, max(P_grid_cmd,0))  / 1000;
Grid_Export_kWh = abs(trapz(time, min(P_grid_cmd,0))) / 1000;

Renewable_Pct   = (PV_Energy_kWh / Load_Energy_kWh) * 100;
Grid_Dependency = (Grid_Import_kWh / Load_Energy_kWh) * 100;

%% ── STEP 9: Display Results ──────────────────────────────────────
fprintf('========== Objective 4 Performance Results ==========\n\n');
fprintf('PV Energy Generated:          %.2f kWh\n', PV_Energy_kWh);
fprintf('Total Load Energy:            %.2f kWh\n', Load_Energy_kWh);
fprintf('\n--- Battery ---\n');
fprintf('Battery Charged:              %.2f kWh\n', Bat_Charge_kWh);
fprintf('Battery Discharged:           %.2f kWh\n', Bat_Disch_kWh);
fprintf('Final Battery SOC:            %.1f %%\n',  SOC_bat(end)*100);
fprintf('\n--- Supercapacitor ---\n');
fprintf('Supercapacitor Charged:       %.2f kWh\n', SC_Charge_kWh);
fprintf('Supercapacitor Discharged:    %.2f kWh\n', SC_Disch_kWh);
fprintf('Final SC Voltage:             %.1f V\n',   V_sc(end));
fprintf('\n--- Flywheel ---\n');
fprintf('Flywheel Charged:             %.2f kWh\n', FW_Charge_kWh);
fprintf('Flywheel Discharged:          %.2f kWh\n', FW_Disch_kWh);
fprintf('Final Flywheel Speed:         %.1f RPM\n', Speed_fw(end));
fprintf('\n--- Grid ---\n');
fprintf('Grid Import Energy:           %.2f kWh\n', Grid_Import_kWh);
fprintf('Grid Export Energy:           %.2f kWh\n', Grid_Export_kWh);
fprintf('\n--- Summary ---\n');
fprintf('Renewable Contribution:       %.1f %%\n',  Renewable_Pct);
fprintf('Grid Dependency:              %.1f %%\n',  Grid_Dependency);

%% ── STEP 10: Plots ───────────────────────────────────────────────

%% Plot 1: Solar Irradiance
figure('Name','Irradiance');
plot(time, Irradiance, 'Color',[0.9 0.6 0.1], 'LineWidth', 2);
xlabel('Time (Hours)'); ylabel('Irradiance (W/m^2)');
title('Solar Irradiance Profile — 24 Hours');
grid on; xlim([0 24]); xticks(0:2:24);

%% Plot 2: PV Power
figure('Name','PV Power');
plot(time, PV_Power_W/1000, 'Color',[0.2 0.7 0.3], 'LineWidth', 2);
xlabel('Time (Hours)'); ylabel('Power (kW)');
title('PV Power Output — Bus 2');
grid on; xlim([0 24]); xticks(0:2:24);

%% Plot 3: All HESS Power Commands
figure('Name','HESS Power Commands');
hold on;
plot(time, P_bat_cmd/1000, 'b-',  'LineWidth',2, 'DisplayName','Battery (kW)');
plot(time, P_sc_cmd/1000,  'r-',  'LineWidth',2, 'DisplayName','Supercapacitor (kW)');
plot(time, P_fw_cmd/1000,  'g-',  'LineWidth',2, 'DisplayName','Flywheel (kW)');
plot(time, P_grid_cmd/1000,'k--', 'LineWidth',1.5,'DisplayName','Grid (kW)');
hold off;
xlabel('Time (Hours)'); ylabel('Power (kW)');
title('HESS Power Commands — All Storage Devices');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);
yline(0,'k:','LineWidth',1);

%% Plot 4: Battery SOC
figure('Name','Battery SOC');
plot(time, SOC_bat*100, 'b-', 'LineWidth', 2);
xlabel('Time (Hours)'); ylabel('SOC (%)');
title('Battery State of Charge — 24 Hours');
ylim([0 100]); grid on;
xlim([0 24]); xticks(0:2:24);
yline(Battery.SOC_max*100,'r--','Max','LineWidth',1);
yline(Battery.SOC_min*100,'r--','Min','LineWidth',1);

%% Plot 5: Supercapacitor Voltage
figure('Name','Supercapacitor Voltage');
plot(time, V_sc, 'r-', 'LineWidth', 2);
xlabel('Time (Hours)'); ylabel('Voltage (V)');
title('Supercapacitor Voltage — 24 Hours');
grid on; xlim([0 24]); xticks(0:2:24);
yline(SuperCap.Voltage_max,'r--','Max','LineWidth',1);
yline(SuperCap.Voltage_min,'r--','Min','LineWidth',1);

%% Plot 6: Flywheel Speed
figure('Name','Flywheel Speed');
plot(time, Speed_fw, 'g-', 'LineWidth', 2);
xlabel('Time (Hours)'); ylabel('Speed (RPM)');
title('Flywheel Speed — 24 Hours');
grid on; xlim([0 24]); xticks(0:2:24);
yline(Flywheel.Speed_max,'r--','Max','LineWidth',1);
yline(Flywheel.Speed_min,'r--','Min','LineWidth',1);

%% Plot 7: All Generator Outputs — IEEE 14 Bus
figure('Name','All Generator Outputs');
gen_colors = {'b','r','g','m','c'};
gen_labels = {'Gen 1 (Bus 1)','Gen 2 (Bus 2)',...
              'Gen 3 (Bus 3)','Gen 4 (Bus 6)',...
              'Gen 5 (Bus 8)'};
hold on;
for g = 1:num_gen
    plot(time, Gen_Output(:,g), ...
        'Color', gen_colors{g}, ...
        'LineWidth', 1.5, ...
        'DisplayName', gen_labels{g});
end
hold off;
xlabel('Time (Hours)'); ylabel('Generator Output (MW)');
title('All Generator Outputs — IEEE 14 Bus with PV+HESS');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);

%% Plot 8: Power Balance
figure('Name','Power Balance');
hold on;
plot(time, PV_Power_W/1000,    'g-',  'LineWidth',2, 'DisplayName','PV (kW)');
plot(time, Load_Power_W/1000,  'r-',  'LineWidth',2, 'DisplayName','Load (kW)');
plot(time, P_grid_cmd/1000,    'k--', 'LineWidth',1.5,'DisplayName','Grid (kW)');
hold off;
xlabel('Time (Hours)'); ylabel('Power (kW)');
title('Power Balance — PV + HESS + Grid');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);

fprintf('\nAll plots generated. Objective 4 complete!\n');