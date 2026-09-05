%% IEEE14_PV_Injection_OPF_Fixed.m
% Objective 3: PV + BESS injected into IEEE 14 Bus Grid
% FIXES:
%   1. PV scaled to 150 MW — large enough to trigger OPF generator redispatch
%   2. Battery SOC min limit properly enforced via EMS
%   3. Bus 2 generator reduction now visible when PV rises

clc;
clear;
Parameters_BESS;

%% Override parameters — scaled for IEEE 14 Bus visibility
PV_Rated_Power              = 150000000;  % 150 MW — large enough to affect grid
Load_Rated_Power            = 5000000;    % 5 MW local load
Battery_Capacity            = 50000000;   % 50 MWh
Battery_Max_Charge_Power    = 20000000;   % 20 MW
Battery_Max_Discharge_Power = 20000000;   % 20 MW
Battery_SOC_Max             = 100;
Battery_SOC_Min             = 20;         % 20% hard floor
Battery_SOC_Initial         = 80;
Battery_Charge_Efficiency   = 0.95;
Battery_Discharge_Efficiency = 0.95;

%% Time vector and profiles
time      = 0:Time_Step:24;
num_steps = length(time);

Irradiance   = Solar_Profile(time);
PV_Power_W   = PV_Model(Irradiance, PV_Rated_Power);
Load_Power_W = Load_Model(time, Load_Rated_Power);
PV_Power_MW  = PV_Power_W / 1e6;

fprintf('IEEE 14 Bus PV + BESS (Fixed)\n');
fprintf('Peak PV Power:   %.1f MW\n',   max(PV_Power_MW));
fprintf('Grid Total Load: 259 MW\n');
fprintf('PV Penetration:  %.1f%%\n\n', (max(PV_Power_MW)/259)*100);

%% Load IEEE 14 Bus
mpc     = case14;
baseMVA = mpc.baseMVA;
PV_Bus  = 2;
gen_idx = find(mpc.gen(:,1) == PV_Bus);

%% Battery SOC tracking with proper min/max enforcement
SOC_BESS      = zeros(num_steps, 1);
SOC_BESS(1)   = Battery_SOC_Initial;
Bat_Cmd_W     = zeros(num_steps, 1);
Grid_BESS_W   = zeros(num_steps, 1);

for k = 1:num_steps
    Power_Error = PV_Power_W(k) - Load_Power_W(k);

    if Power_Error > 0
        %% PV surplus — charge battery only if below max
        if SOC_BESS(k) < Battery_SOC_Max
            Bat_Cmd_W(k) = min(Power_Error, Battery_Max_Charge_Power);
        else
            Bat_Cmd_W(k) = 0;
        end
    elseif Power_Error < 0
        %% PV deficit — discharge battery only if above min
        if SOC_BESS(k) > Battery_SOC_Min
            Bat_Cmd_W(k) = max(Power_Error, -Battery_Max_Discharge_Power);
        else
            %% Battery at minimum — grid must cover remainder
            Bat_Cmd_W(k) = 0;
        end
    end

    %% Grid covers what battery cannot
    Grid_BESS_W(k) = Load_Power_W(k) - PV_Power_W(k) - Bat_Cmd_W(k);

    %% Update SOC for next step
    if k < num_steps
        Energy_Change = Bat_Cmd_W(k) * Time_Step;
        if Bat_Cmd_W(k) >= 0
            Energy_Change = Energy_Change * Battery_Charge_Efficiency;
        else
            Energy_Change = Energy_Change / Battery_Discharge_Efficiency;
        end
        SOC_new = SOC_BESS(k) + (Energy_Change / Battery_Capacity) * 100;
        %% Hard enforce SOC limits
        SOC_new = max(min(SOC_new, Battery_SOC_Max), Battery_SOC_Min);
        SOC_BESS(k+1) = SOC_new;
    end
end

fprintf('SOC min reached: %.1f%%\n',   min(SOC_BESS));
fprintf('SOC max reached: %.1f%%\n\n', max(SOC_BESS));

%% Run 24 Hour OPF
num_gen     = size(mpc.gen, 1);
Gen_Output  = zeros(num_steps, num_gen);
Bus2_Gen    = zeros(num_steps, 1);
PV_Injected = zeros(num_steps, 1);
OPF_Success = zeros(num_steps, 1);

fprintf('Running 24-hour OPF...\n');

for k = 1:num_steps
    mpc_k = mpc;

    %% Net PV after battery (convert to MW)
    Net_PV_MW = (PV_Power_W(k) - max(Bat_Cmd_W(k), 0)) / 1e6;
    Net_PV_MW = max(Net_PV_MW, 0);

    %% Reduce Bus 2 generator max by PV amount
    orig_Pmax = mpc_k.gen(gen_idx, 9);
    orig_Pmin = mpc_k.gen(gen_idx, 10);
    new_Pmax  = max(orig_Pmax - Net_PV_MW, 0);
    mpc_k.gen(gen_idx, 9)  = new_Pmax;
    mpc_k.gen(gen_idx, 10) = min(orig_Pmin, new_Pmax);

    mpopt     = mpoption('verbose', 0, 'out.all', 0);
    results_k = runopf(mpc_k, mpopt);

    if results_k.success
        Gen_Output(k,:) = results_k.gen(:,2)';
        Bus2_Gen(k)     = results_k.gen(gen_idx, 2);
        PV_Injected(k)  = Net_PV_MW;
        OPF_Success(k)  = 1;
    else
        if k > 1
            Gen_Output(k,:) = Gen_Output(k-1,:);
            Bus2_Gen(k)     = Bus2_Gen(k-1);
        end
    end

    if mod(k, 500) == 0
        fprintf('  Hour %.1f / 24\n', time(k));
    end
end

fprintf('\nConvergence: %.1f%%\n\n', (sum(OPF_Success)/num_steps)*100);

%% Performance metrics
S2_PV_Energy     = trapz(time, PV_Power_W)             / 1000;
S2_Load_Energy   = trapz(time, Load_Power_W)           / 1000;
S2_Grid_Import   = trapz(time, max(Grid_BESS_W,0))     / 1000;
S2_Grid_Export   = abs(trapz(time,min(Grid_BESS_W,0))) / 1000;
S2_Renewable_Pct = (S2_PV_Energy/S2_Load_Energy)       * 100;
S2_Grid_Dep      = (S2_Grid_Import/S2_Load_Energy)     * 100;

fprintf('PV Energy:           %.2f kWh\n', S2_PV_Energy);
fprintf('Grid Import:         %.2f kWh\n', S2_Grid_Import);
fprintf('Renewable %%:         %.1f%%\n',  S2_Renewable_Pct);
fprintf('Grid Dependency:     %.1f%%\n\n', S2_Grid_Dep);

%% ── PLOTS ────────────────────────────────────────────────────────

%% Plot 1 — Solar Irradiance
figure('Name','Irradiance');
plot(time, Irradiance, 'Color',[0.9 0.6 0.1], 'LineWidth',2);
xlabel('Time (Hours)'); ylabel('Irradiance (W/m^2)');
title('Solar Irradiance Profile — 24 Hours');
grid on; xlim([0 24]); xticks(0:2:24);

%% Plot 2 — PV Power Output
figure('Name','PV Power');
plot(time, PV_Power_W/1e6, 'Color',[0.2 0.7 0.3], 'LineWidth',2);
xlabel('Time (Hours)'); ylabel('Power (MW)');
title('PV Power Output — Bus 2 (150 MW Rated)');
grid on; xlim([0 24]); xticks(0:2:24);

%% Plot 3 — All Generator Outputs
figure('Name','All Generator Outputs — IEEE 14 Bus');
gen_colors = {[0 0.4 0.8],[0.8 0.2 0.2],[0.2 0.7 0.3],[0.8 0.2 0.8],[0.1 0.8 0.8]};
gen_labels = {'Gen 1 (Bus 1)','Gen 2 (Bus 2)','Gen 3 (Bus 3)',...
              'Gen 4 (Bus 6)','Gen 5 (Bus 8)'};
hold on;
for g = 1:num_gen
    plot(time, Gen_Output(:,g), 'Color',gen_colors{g}, ...
        'LineWidth',1.5, 'DisplayName',gen_labels{g});
end
hold off;
xlabel('Time (Hours)'); ylabel('Generator Output (MW)');
title('All Generator Outputs — IEEE 14 Bus with PV+BESS');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);

%% Plot 4 — Bus 2 Generator vs PV Injection
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

%% Plot 5 — Battery SOC with proper limits
figure('Name','Battery SOC');
plot(time, SOC_BESS, 'b-', 'LineWidth',2);
xlabel('Time (Hours)'); ylabel('SOC (%)');
title('Battery State of Charge — 24 Hours');
yline(Battery_SOC_Max,'r--','Max','LineWidth',1.5);
yline(Battery_SOC_Min,'r--','Min','LineWidth',1.5);
ylim([0 110]); grid on;
xlim([0 24]); xticks(0:2:24);

%% Plot 6 — Power Balance
figure('Name','Power Balance — PV + BESS + Grid');
hold on;
plot(time, PV_Power_W/1e6,        'g-',  'LineWidth',2, ...
    'DisplayName','PV (MW)');
plot(time, Load_Power_W/1e6,      'r-',  'LineWidth',2, ...
    'DisplayName','Load (MW)');
plot(time, Bat_Cmd_W/1e6,         'b--', 'LineWidth',1.5, ...
    'DisplayName','Battery (MW)');
plot(time, Grid_BESS_W/1e6,       'k-',  'LineWidth',1.5, ...
    'DisplayName','Grid (MW)');
hold off;
xlabel('Time (Hours)'); ylabel('Power (MW)');
title('Power Balance — PV + BESS + Grid');
legend('Location','best'); grid on;
xlim([0 24]); xticks(0:2:24);
yline(0,'k:','LineWidth',0.5);

fprintf('All plots generated. Objective 3 Fixed complete!\n');
