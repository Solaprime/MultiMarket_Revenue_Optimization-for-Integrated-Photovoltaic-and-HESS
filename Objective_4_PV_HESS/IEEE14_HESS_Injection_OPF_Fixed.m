%% IEEE14_HESS_Injection_OPF_Fixed.m
% Objective 4: PV + HESS injected into IEEE 14 Bus Grid
% FIXES:
%   1. PV scaled to 150 MW — triggers visible generator redispatch
%   2. Flywheel charges during surplus PV before battery
%   3. All storage SOC/voltage/speed limits properly enforced

clc;
clear;
Parameters_HESS;

%% Override PV scale to match fixed BESS script
PV_Rated_Power   = 150000000;  % 150 MW
Load_Rated_Power = 5000000;    % 5 MW

%% Time vector
time      = 0:Time_Step:24;
num_steps = length(time);

Irradiance   = Solar_Profile(time);
PV_Power_W   = PV_Model(Irradiance, PV_Rated_Power);
Load_Power_W = Load_Model(time, Load_Rated_Power);
PV_Power_MW  = PV_Power_W / 1e6;

fprintf('IEEE 14 Bus PV + HESS (Fixed)\n');
fprintf('Peak PV Power:   %.1f MW\n',   max(PV_Power_MW));
fprintf('PV Penetration:  %.1f%%\n\n', (max(PV_Power_MW)/259)*100);

%% Load IEEE 14 Bus
mpc     = case14;
PV_Bus  = 2;
gen_idx = find(mpc.gen(:,1) == PV_Bus);

%% Initialise storage states
SOC_bat_H  = zeros(num_steps,1); SOC_bat_H(1)  = Battery.SOC_initial;
V_sc_H     = zeros(num_steps,1); V_sc_H(1)     = SuperCap.Voltage_init;
Speed_fw_H = zeros(num_steps,1); Speed_fw_H(1) = Flywheel.Speed_init;

P_bat_H  = zeros(num_steps,1);
P_sc_H   = zeros(num_steps,1);
P_fw_H   = zeros(num_steps,1);
P_grid_H = zeros(num_steps,1);

%% IEEE 14 Bus tracking
num_gen    = size(mpc.gen,1);
Gen_Output = zeros(num_steps,num_gen);
Bus2_Gen   = zeros(num_steps,1);
PV_Injected = zeros(num_steps,1);
OPF_Success = zeros(num_steps,1);

fprintf('Running 24-hour HESS simulation...\n');

for k = 1:num_steps
    Power_Error = PV_Power_W(k) - Load_Power_W(k);
    Remaining   = Power_Error;

    %% ── SUPERCAPACITOR first ─────────────────────────────────────
    if Remaining > 0
        if V_sc_H(k) < SuperCap.Voltage_max
            P_sc_H(k) = min(Remaining, SuperCap.Max_Power);
            Remaining  = Remaining - P_sc_H(k);
        end
    elseif Remaining < 0
        if V_sc_H(k) > SuperCap.Voltage_min
            P_sc_H(k) = max(Remaining, -SuperCap.Max_Power);
            Remaining  = Remaining - P_sc_H(k);
        end
    end

    %% ── FLYWHEEL second ──────────────────────────────────────────
    if Remaining > 0
        if Speed_fw_H(k) < Flywheel.Speed_max
            P_fw_H(k) = min(Remaining, Flywheel.Max_Power);
            Remaining  = Remaining - P_fw_H(k);
        end
    elseif Remaining < 0
        if Speed_fw_H(k) > Flywheel.Speed_min
            P_fw_H(k) = max(Remaining, -Flywheel.Max_Power);
            Remaining  = Remaining - P_fw_H(k);
        end
    end

    %% ── BATTERY last ─────────────────────────────────────────────
    if Remaining > 0
        if SOC_bat_H(k) < Battery.SOC_max
            P_bat_H(k) = min(Remaining, Battery.Max_charge_power);
            Remaining   = Remaining - P_bat_H(k);
        end
    elseif Remaining < 0
        if SOC_bat_H(k) > Battery.SOC_min
            P_bat_H(k) = max(Remaining, -Battery.Max_discharge_power);
            Remaining   = Remaining - P_bat_H(k);
        end
    end

    %% Grid covers remainder
    P_grid_H(k) = -Remaining;

    %% Update storage states for next step
    if k < num_steps
        %% Battery SOC update with hard limits
        E_change = P_bat_H(k) * Time_Step;
        if P_bat_H(k) >= 0
            E_change = E_change * Battery.Charge_efficiency;
        else
            E_change = E_change / Battery.Discharge_efficiency;
        end
        SOC_new = SOC_bat_H(k) + E_change / Battery.Capacity;
        SOC_bat_H(k+1) = max(min(SOC_new, Battery.SOC_max), Battery.SOC_min);

        %% Supercapacitor voltage update
        [V_sc_H(k+1), ~] = Supercapacitor_Model(...
            P_sc_H(k), V_sc_H(k), Time_Step, SuperCap);

        %% Flywheel speed update
        [Speed_fw_H(k+1), ~] = Flywheel_Model(...
            P_fw_H(k), Speed_fw_H(k), Time_Step, Flywheel);
    end

    %% Run OPF
    mpc_k = mpc;
    Net_PV_MW = (PV_Power_W(k) - max(P_bat_H(k),0) - ...
        max(P_sc_H(k),0) - max(P_fw_H(k),0)) / 1e6;
    Net_PV_MW = max(Net_PV_MW, 0);

    orig_Pmax = mpc_k.gen(gen_idx,9);
    orig_Pmin = mpc_k.gen(gen_idx,10);
    new_Pmax  = max(orig_Pmax - Net_PV_MW, 0);
    mpc_k.gen(gen_idx,9)  = new_Pmax;
    mpc_k.gen(gen_idx,10) = min(orig_Pmin, new_Pmax);

    mpopt     = mpoption('verbose',0,'out.all',0);
    results_k = runopf(mpc_k, mpopt);

    if results_k.success
        Gen_Output(k,:) = results_k.gen(:,2)';
        Bus2_Gen(k)     = results_k.gen(gen_idx,2);
        PV_Injected(k)  = Net_PV_MW;
        OPF_Success(k)  = 1;
    else
        if k > 1
            Gen_Output(k,:) = Gen_Output(k-1,:);
            Bus2_Gen(k)     = Bus2_Gen(k-1);
        end
    end

    if mod(k,500) == 0
        fprintf('  Hour %.1f / 24\n', time(k));
    end
end

fprintf('\nConvergence: %.1f%%\n\n', (sum(OPF_Success)/num_steps)*100);

%% Performance metrics
S3_PV_Energy     = trapz(time, PV_Power_W)           / 1000;
S3_Load_Energy   = trapz(time, Load_Power_W)         / 1000;
S3_Grid_Import   = trapz(time, max(P_grid_H,0))      / 1000;
S3_Grid_Export   = abs(trapz(time,min(P_grid_H,0)))  / 1000;
S3_Renewable_Pct = (S3_PV_Energy/S3_Load_Energy)     * 100;
S3_Grid_Dep      = (S3_Grid_Import/S3_Load_Energy)   * 100;

fprintf('PV Energy:       %.2f kWh\n', S3_PV_Energy);
fprintf('Grid Import:     %.2f kWh\n', S3_Grid_Import);
fprintf('Renewable %%:     %.1f%%\n',  S3_Renewable_Pct);
fprintf('Grid Dependency: %.1f%%\n\n', S3_Grid_Dep);
fprintf('Battery SOC min: %.1f%% (should be above %.0f%%)\n', ...
    min(SOC_bat_H*100), Battery.SOC_min*100);
fprintf('Flywheel max speed reached: %.0f RPM\n',   max(Speed_fw_H));
fprintf('Flywheel min speed reached: %.0f RPM\n\n', min(Speed_fw_H));

%% ── PLOTS ────────────────────────────────────────────────────────

%% Plot 1 — Irradiance
figure('Name','Irradiance');
plot(time, Irradiance, 'Color',[0.9 0.6 0.1], 'LineWidth',2);
xlabel('Time (Hours)'); ylabel('Irradiance (W/m^2)');
title('Solar Irradiance Profile — 24 Hours');
grid on; xlim([0 24]); xticks(0:2:24);

%% Plot 2 — PV Power
figure('Name','PV Power');
plot(time, PV_Power_W/1e6, 'Color',[0.2 0.7 0.3], 'LineWidth',2);
xlabel('Time (Hours)'); ylabel('Power (MW)');
title('PV Power Output — Bus 2 (150 MW Rated)');
grid on; xlim([0 24]); xticks(0:2:24);

%% Plot 3 — All Generator Outputs
figure('Name','All Generator Outputs — IEEE 14 Bus with PV+HESS');
gen_colors = {[0 0.4 0.8],[0.8 0.2 0.2],[0.2 0.7 0.3],...
              [0.8 0.2 0.8],[0.1 0.8 0.8]};
gen_labels = {'Gen 1 (Bus 1)','Gen 2 (Bus 2)','Gen 3 (Bus 3)',...
              'Gen 4 (Bus 6)','Gen 5 (Bus 8)'};
hold on;
for g = 1:num_gen
    plot(time, Gen_Output(:,g), 'Color',gen_colors{g}, ...
        'LineWidth',1.5, 'DisplayName',gen_labels{g});
end
hold off;
xlabel('Time (Hours)'); ylabel('Generator Output (MW)');
title('All Generator Outputs — IEEE 14 Bus with PV+HESS');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);

%% Plot 4 — Bus 2 Generator vs PV
figure('Name','Bus 2 — Generator vs PV');
hold on;
plot(time, Bus2_Gen,    'b-', 'LineWidth',2, ...
    'DisplayName','Bus 2 Generator (MW)');
plot(time, PV_Injected, 'g-', 'LineWidth',2, ...
    'DisplayName','Net PV Injected (MW)');
hold off;
xlabel('Time (Hours)'); ylabel('Power (MW)');
title('Bus 2 — Generator Output vs PV Injection');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);

%% Plot 5 — HESS Power Commands
figure('Name','HESS Power Commands');
hold on;
plot(time, P_bat_H/1e6,  'b-',  'LineWidth',2, ...
    'DisplayName','Battery (MW)');
plot(time, P_sc_H/1e6,   'r-',  'LineWidth',2, ...
    'DisplayName','Supercapacitor (MW)');
plot(time, P_fw_H/1e6,   'g-',  'LineWidth',2, ...
    'DisplayName','Flywheel (MW)');
plot(time, P_grid_H/1e6, 'k--', 'LineWidth',1.5, ...
    'DisplayName','Grid (MW)');
hold off;
xlabel('Time (Hours)'); ylabel('Power (MW)');
title('HESS Power Commands — All Storage Devices');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);
yline(0,'k:','LineWidth',0.5);

%% Plot 6 — Battery SOC
figure('Name','Battery SOC');
plot(time, SOC_bat_H*100, 'b-', 'LineWidth',2);
xlabel('Time (Hours)'); ylabel('SOC (%)');
title('Battery State of Charge — 24 Hours');
yline(Battery.SOC_max*100,'r--','Max','LineWidth',1.5);
yline(Battery.SOC_min*100,'r--','Min','LineWidth',1.5);
ylim([0 110]); grid on;
xlim([0 24]); xticks(0:2:24);

%% Plot 7 — Supercapacitor Voltage
figure('Name','Supercapacitor Voltage');
plot(time, V_sc_H, 'r-', 'LineWidth',2);
xlabel('Time (Hours)'); ylabel('Voltage (V)');
title('Supercapacitor Voltage — 24 Hours');
yline(SuperCap.Voltage_max,'r--','Max','LineWidth',1.5);
yline(SuperCap.Voltage_min,'r--','Min','LineWidth',1.5);
grid on; xlim([0 24]); xticks(0:2:24);

%% Plot 8 — Flywheel Speed
figure('Name','Flywheel Speed');
plot(time, Speed_fw_H, 'g-', 'LineWidth',2);
xlabel('Time (Hours)'); ylabel('Speed (RPM)');
title('Flywheel Speed — 24 Hours');
yline(Flywheel.Speed_max,'r--','Max','LineWidth',1.5);
yline(Flywheel.Speed_min,'r--','Min','LineWidth',1.5);
grid on; xlim([0 24]); xticks(0:2:24);

%% Plot 9 — Power Balance
figure('Name','Power Balance — PV + HESS + Grid');
hold on;
plot(time, PV_Power_W/1e6,  'g-',  'LineWidth',2, ...
    'DisplayName','PV (MW)');
plot(time, Load_Power_W/1e6,'r-',  'LineWidth',2, ...
    'DisplayName','Load (MW)');
plot(time, P_grid_H/1e6,    'k--', 'LineWidth',1.5, ...
    'DisplayName','Grid (MW)');
hold off;
xlabel('Time (Hours)'); ylabel('Power (MW)');
title('Power Balance — PV + HESS + Grid');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);
yline(0,'k:','LineWidth',0.5);

fprintf('All plots generated. Objective 4 Fixed complete!\n');
