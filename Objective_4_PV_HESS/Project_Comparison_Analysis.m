%% Project_Comparison_Analysis_Fixed.m
% Comprehensive Analysis — All 3 Areas
%
% AREA 1: Direct comparison of all 3 scenarios
%         No Storage vs PV+BESS vs PV+HESS
%
% AREA 2: Battery Degradation Analysis
%
% AREA 3: Economic Analysis
%
% NOTE: This script uses Parameters_BESS variables directly
%       for Scenario 2 (not the Battery struct from Objective 1)
%       to avoid input argument conflicts between model versions.

clc;
clear;

fprintf('================================================\n');
fprintf('  Comprehensive Project Comparison Analysis\n');
fprintf('  Area 1: Scenario Comparison\n');
fprintf('  Area 2: Battery Degradation\n');
fprintf('  Area 3: Economic Analysis\n');
fprintf('================================================\n\n');

%% ── SHARED SETUP ─────────────────────────────────────────────────
Parameters_BESS;

%% Override for IEEE 14 Bus scale
PV_Rated_Power              = 15000000;  % 15 MW
Load_Rated_Power            = 5000000;   % 5 MW
Battery_Capacity            = 10000000;  % 10 MWh
Battery_Max_Charge_Power    = 3000000;   % 3 MW
Battery_Max_Discharge_Power = 3000000;   % 3 MW
Battery_SOC_Max             = 100;
Battery_SOC_Min             = 20;
Battery_SOC_Initial         = 80;
Battery_Charge_Efficiency   = 0.95;
Battery_Discharge_Efficiency = 0.95;

%% Time vector and profiles
time      = 0:Time_Step:24;
num_steps = length(time);

Irradiance   = Solar_Profile(time);
PV_Power_W   = PV_Model(Irradiance, PV_Rated_Power);
Load_Power_W = Load_Model(time, Load_Rated_Power);

%% ════════════════════════════════════════════════════════════════
%% SCENARIO 1 — No Storage (Baseline)
%% ════════════════════════════════════════════════════════════════
fprintf('Running Scenario 1 — No Storage (Baseline)...\n');

Grid_NoStorage   = max(Load_Power_W - PV_Power_W, 0);
Export_NoStorage = max(PV_Power_W - Load_Power_W, 0);

S1_PV_Energy     = trapz(time, PV_Power_W)       / 1000;
S1_Load_Energy   = trapz(time, Load_Power_W)     / 1000;
S1_Grid_Import   = trapz(time, Grid_NoStorage)   / 1000;
S1_Grid_Export   = trapz(time, Export_NoStorage) / 1000;
S1_Renewable_Pct = (S1_PV_Energy / S1_Load_Energy)   * 100;
S1_Grid_Dep      = (S1_Grid_Import / S1_Load_Energy) * 100;

fprintf('  PV Energy:        %.2f kWh\n', S1_PV_Energy);
fprintf('  Grid Import:      %.2f kWh\n', S1_Grid_Import);
fprintf('  Renewable %%:      %.1f%%\n',  S1_Renewable_Pct);
fprintf('  Grid Dependency:  %.1f%%\n\n', S1_Grid_Dep);

%% ════════════════════════════════════════════════════════════════
%% SCENARIO 2 — PV + BESS
%% Uses Parameters_BESS variables directly — avoids struct conflict
%% ════════════════════════════════════════════════════════════════
fprintf('Running Scenario 2 — PV + BESS...\n');

%% Raw power balance — how much surplus or deficit at each step
Power_Balance_W = PV_Power_W - Load_Power_W;

%% Build raw battery power command
Bat_Raw_W = zeros(size(time));
for k = 1:num_steps
    if Power_Balance_W(k) > 0
        % PV surplus — charge battery
        Bat_Raw_W(k) = min(Power_Balance_W(k), ...
            Battery_Max_Charge_Power);
    elseif Power_Balance_W(k) < 0
        % PV deficit — discharge battery
        Bat_Raw_W(k) = max(Power_Balance_W(k), ...
            -Battery_Max_Discharge_Power);
    end
end

%% Track SOC using existing SOC_Model
SOC_BESS = SOC_Model(...
    Bat_Raw_W, ...
    Battery_SOC_Initial, ...
    Battery_Capacity, ...
    Battery_Charge_Efficiency, ...
    Time_Step);

%% Apply EMS with SOC constraints
[Bat_Cmd_W, Grid_BESS_W] = Energy_Management(...
    PV_Power_W, ...
    Load_Power_W, ...
    SOC_BESS, ...
    Battery_SOC_Max, ...
    Battery_SOC_Min, ...
    Battery_Max_Charge_Power, ...
    Battery_Max_Discharge_Power);

%% Energy calculations
S2_PV_Energy     = trapz(time, PV_Power_W)                  / 1000;
S2_Load_Energy   = trapz(time, Load_Power_W)                / 1000;
S2_Grid_Import   = trapz(time, max(Grid_BESS_W, 0))         / 1000;
S2_Grid_Export   = abs(trapz(time, min(Grid_BESS_W, 0)))    / 1000;
S2_Bat_Charge    = trapz(time, max(Bat_Cmd_W, 0))           / 1000;
S2_Bat_Discharge = abs(trapz(time, min(Bat_Cmd_W, 0)))      / 1000;
S2_Renewable_Pct = (S2_PV_Energy / S2_Load_Energy)          * 100;
S2_Grid_Dep      = (S2_Grid_Import / S2_Load_Energy)        * 100;

fprintf('  PV Energy:        %.2f kWh\n', S2_PV_Energy);
fprintf('  Grid Import:      %.2f kWh\n', S2_Grid_Import);
fprintf('  Renewable %%:      %.1f%%\n',  S2_Renewable_Pct);
fprintf('  Grid Dependency:  %.1f%%\n\n', S2_Grid_Dep);

%% ════════════════════════════════════════════════════════════════
%% SCENARIO 3 — PV + HESS
%% Uses Parameters_HESS struct format — matches HESS models
%% ════════════════════════════════════════════════════════════════
fprintf('Running Scenario 3 — PV + HESS...\n');

%% Load HESS parameters
Parameters_HESS;

%% Initialise all storage states
SOC_bat_H  = zeros(num_steps, 1);
SOC_bat_H(1) = Battery.SOC_initial;

V_sc_H     = zeros(num_steps, 1);
V_sc_H(1)  = SuperCap.Voltage_init;

Speed_fw_H = zeros(num_steps, 1);
Speed_fw_H(1) = Flywheel.Speed_init;

P_bat_H    = zeros(num_steps, 1);
P_sc_H     = zeros(num_steps, 1);
P_fw_H     = zeros(num_steps, 1);
P_grid_H   = zeros(num_steps, 1);

%% Run HESS simulation
for k = 1:num_steps
    Power_Error = PV_Power_W(k) - Load_Power_W(k);

    [P_bat_H(k), P_sc_H(k), P_fw_H(k), P_grid_H(k)] = HESS_EMS(...
        Power_Error, ...
        SOC_bat_H(k), ...
        V_sc_H(k), ...
        Speed_fw_H(k), ...
        Battery, ...
        SuperCap, ...
        Flywheel);

    if k < num_steps
        [SOC_bat_H(k+1), ~, ~] = Battery_Model(...
            P_bat_H(k), SOC_bat_H(k), Time_Step, Battery);
        [V_sc_H(k+1), ~] = Supercapacitor_Model(...
            P_sc_H(k), V_sc_H(k), Time_Step, SuperCap);
        [Speed_fw_H(k+1), ~] = Flywheel_Model(...
            P_fw_H(k), Speed_fw_H(k), Time_Step, Flywheel);
    end
end

%% Energy calculations
S3_PV_Energy     = trapz(time, PV_Power_W)                  / 1000;
S3_Load_Energy   = trapz(time, Load_Power_W)                / 1000;
S3_Grid_Import   = trapz(time, max(P_grid_H, 0))            / 1000;
S3_Grid_Export   = abs(trapz(time, min(P_grid_H, 0)))       / 1000;
S3_Bat_Charge    = trapz(time, max(P_bat_H, 0))             / 1000;
S3_SC_Charge     = trapz(time, max(P_sc_H, 0))              / 1000;
S3_FW_Charge     = trapz(time, max(P_fw_H, 0))              / 1000;
S3_Renewable_Pct = (S3_PV_Energy / S3_Load_Energy)          * 100;
S3_Grid_Dep      = (S3_Grid_Import / S3_Load_Energy)        * 100;

fprintf('  PV Energy:        %.2f kWh\n', S3_PV_Energy);
fprintf('  Grid Import:      %.2f kWh\n', S3_Grid_Import);
fprintf('  Renewable %%:      %.1f%%\n',  S3_Renewable_Pct);
fprintf('  Grid Dependency:  %.1f%%\n\n', S3_Grid_Dep);

%% ════════════════════════════════════════════════════════════════
%% AREA 1 — DIRECT COMPARISON PLOTS
%% ════════════════════════════════════════════════════════════════
fprintf('Generating Area 1 — Comparison Plots...\n');

scenarios  = {'No Storage', 'PV + BESS', 'PV + HESS'};
clr        = [0.8 0.2 0.2; 0.2 0.6 0.8; 0.2 0.7 0.3];

%% Comparison Plot 1 — Grid Dependency
figure('Name','Comparison 1 — Grid Dependency');
bar_vals = [S1_Grid_Dep, S2_Grid_Dep, S3_Grid_Dep];
b = bar(bar_vals, 0.5);
b.FaceColor = 'flat';
b.CData = clr;
set(gca,'XTickLabel', scenarios);
ylabel('Grid Dependency (%)');
title('Grid Dependency — All 3 Scenarios');
ylim([0 max(bar_vals)*1.2]);
grid on;
for i = 1:3
    text(i, bar_vals(i) + 1, sprintf('%.1f%%', bar_vals(i)), ...
        'HorizontalAlignment','center','FontWeight','bold');
end

%% Comparison Plot 2 — Renewable Contribution
figure('Name','Comparison 2 — Renewable Contribution');
bar_vals2 = [S1_Renewable_Pct, S2_Renewable_Pct, S3_Renewable_Pct];
b2 = bar(bar_vals2, 0.5);
b2.FaceColor = 'flat';
b2.CData = clr;
set(gca,'XTickLabel', scenarios);
ylabel('Renewable Contribution (%)');
title('Renewable Contribution — All 3 Scenarios');
grid on;
for i = 1:3
    text(i, bar_vals2(i) + 1, sprintf('%.1f%%', bar_vals2(i)), ...
        'HorizontalAlignment','center','FontWeight','bold');
end

%% Comparison Plot 3 — Grid Import vs Export
figure('Name','Comparison 3 — Grid Import and Export');
data_grid = [S1_Grid_Import S1_Grid_Export;
             S2_Grid_Import S2_Grid_Export;
             S3_Grid_Import S3_Grid_Export];
b3 = bar(data_grid, 0.6);
b3(1).FaceColor = [0.8 0.3 0.3];
b3(2).FaceColor = [0.3 0.7 0.4];
set(gca,'XTickLabel', scenarios);
ylabel('Energy (kWh)');
title('Grid Import vs Export — All 3 Scenarios');
legend('Grid Import (kWh)', 'Grid Export (kWh)', 'Location','best');
grid on;

%% Comparison Plot 4 — Grid Power Profiles Side by Side
figure('Name','Comparison 4 — Grid Power Profiles');
hold on;
plot(time, Grid_NoStorage/1000,      'r-',  'LineWidth',2, ...
    'DisplayName','No Storage');
plot(time, max(Grid_BESS_W,0)/1000,  'b-',  'LineWidth',2, ...
    'DisplayName','PV + BESS');
plot(time, max(P_grid_H,0)/1000,     'g-',  'LineWidth',2, ...
    'DisplayName','PV + HESS');
hold off;
xlabel('Time (Hours)');
ylabel('Grid Import Power (kW)');
title('Grid Import Power Over 24 Hours — All 3 Scenarios');
legend('Location','best');
grid on;
xlim([0 24]);
xticks(0:2:24);

%% Comparison Plot 5 — SOC Comparison BESS vs HESS Battery
figure('Name','Comparison 5 — Battery SOC');
hold on;
plot(time, SOC_BESS,        'b-', 'LineWidth',2, ...
    'DisplayName','BESS Battery SOC (%)');
plot(time, SOC_bat_H*100,   'g-', 'LineWidth',2, ...
    'DisplayName','HESS Battery SOC (%)');
hold off;
xlabel('Time (Hours)');
ylabel('State of Charge (%)');
title('Battery SOC Comparison — BESS vs HESS');
legend('Location','best');
ylim([0 110]);
grid on;
xlim([0 24]);
xticks(0:2:24);

fprintf('  Area 1 complete — 5 comparison plots generated.\n\n');

%% ════════════════════════════════════════════════════════════════
%% AREA 2 — BATTERY DEGRADATION ANALYSIS
%% ════════════════════════════════════════════════════════════════
fprintf('Generating Area 2 — Battery Degradation Analysis...\n');

%% Degradation parameters
Cycle_Life       = Battery_Cycle_Life;    % from Parameters_BESS
Initial_Capacity = Battery_Initial_Capacity;

%% Daily cycle count — based on discharge energy vs capacity
Daily_Cycles_BESS = S2_Bat_Discharge / (Battery_Capacity/1000);
Daily_Cycles_HESS = trapz(time, abs(min(P_bat_H,0))) / 1000 / ...
    (Battery_Capacity/1000);

%% Lifetime projection
Days_EOL_BESS  = Cycle_Life / max(Daily_Cycles_BESS, 0.001);
Days_EOL_HESS  = Cycle_Life / max(Daily_Cycles_HESS, 0.001);
Years_EOL_BESS = Days_EOL_BESS / 365;
Years_EOL_HESS = Days_EOL_HESS / 365;

%% Capacity fade — linear from 100% to 80% at end of life
days_BESS      = 0:ceil(Days_EOL_BESS);
days_HESS      = 0:ceil(Days_EOL_HESS);
Cap_BESS       = Initial_Capacity - ...
    (Initial_Capacity - 80).*(days_BESS/ceil(Days_EOL_BESS));
Cap_HESS       = Initial_Capacity - ...
    (Initial_Capacity - 80).*(days_HESS/ceil(Days_EOL_HESS));

%% Degradation Plot 1 — Capacity fade BESS vs HESS
figure('Name','Degradation 1 — Capacity Fade Comparison');
hold on;
plot(days_BESS/365, Cap_BESS, 'b-', 'LineWidth',2, ...
    'DisplayName', sprintf('BESS (%.1f yrs)', Years_EOL_BESS));
plot(days_HESS/365, Cap_HESS, 'g-', 'LineWidth',2, ...
    'DisplayName', sprintf('HESS Battery (%.1f yrs)', Years_EOL_HESS));
hold off;
xlabel('Years');
ylabel('Remaining Capacity (%)');
title('Battery Capacity Fade — BESS vs HESS Battery');
yline(80,'r--','End of Life (80%)','LineWidth',1.5);
legend('Location','best');
grid on;
ylim([75 105]);

%% Degradation Plot 2 — Daily SOC BESS vs HESS
figure('Name','Degradation 2 — Daily SOC Profile');
hold on;
plot(time, SOC_BESS,       'b-', 'LineWidth',2, ...
    'DisplayName','BESS SOC (%)');
plot(time, SOC_bat_H*100,  'g-', 'LineWidth',2, ...
    'DisplayName','HESS Battery SOC (%)');
hold off;
xlabel('Time (Hours)');
ylabel('SOC (%)');
title('Daily SOC Profile — BESS vs HESS Battery (Degradation Indicator)');
legend('Location','best');
ylim([0 110]);
grid on;
xlim([0 24]);
xticks(0:2:24);

%% Degradation Plot 3 — Cumulative cycles
figure('Name','Degradation 3 — Cumulative Cycles');
years_vec   = 1:max(ceil(Years_EOL_BESS), ceil(Years_EOL_HESS));
cum_BESS    = Daily_Cycles_BESS * 365 * years_vec;
cum_HESS    = Daily_Cycles_HESS * 365 * years_vec;
hold on;
plot(years_vec, cum_BESS, 'b-', 'LineWidth',2, ...
    'DisplayName','BESS Cycles');
plot(years_vec, cum_HESS, 'g-', 'LineWidth',2, ...
    'DisplayName','HESS Battery Cycles');
yline(Cycle_Life, 'r--', 'Cycle Life Limit', 'LineWidth',1.5);
hold off;
xlabel('Year');
ylabel('Cumulative Cycles');
title('Cumulative Battery Cycles vs Rated Cycle Life');
legend('Location','best');
grid on;

fprintf('  BESS daily cycles:      %.3f\n',  Daily_Cycles_BESS);
fprintf('  HESS battery cycles:    %.3f\n',  Daily_Cycles_HESS);
fprintf('  BESS lifetime:          %.1f years\n', Years_EOL_BESS);
fprintf('  HESS battery lifetime:  %.1f years\n\n', Years_EOL_HESS);

%% ════════════════════════════════════════════════════════════════
%% AREA 3 — ECONOMIC ANALYSIS
%% ════════════════════════════════════════════════════════════════
fprintf('Generating Area 3 — Economic Analysis...\n');

%% Electricity prices
Grid_Import_Price = 0.15;   % USD per kWh
Grid_Export_Price = 0.08;   % USD per kWh
PV_Gen_Cost       = 0.04;   % USD per kWh

%% Daily costs — Scenario 1
S1_Import_Cost = S1_Grid_Import * Grid_Import_Price;
S1_Export_Rev  = S1_Grid_Export * Grid_Export_Price;
S1_PV_Cost     = S1_PV_Energy   * PV_Gen_Cost;
S1_Net_Cost    = S1_Import_Cost + S1_PV_Cost - S1_Export_Rev;

%% Daily costs — Scenario 2
S2_Import_Cost = S2_Grid_Import * Grid_Import_Price;
S2_Export_Rev  = S2_Grid_Export * Grid_Export_Price;
S2_PV_Cost     = S2_PV_Energy   * PV_Gen_Cost;
S2_Net_Cost    = S2_Import_Cost + S2_PV_Cost - S2_Export_Rev;

%% Daily costs — Scenario 3
S3_Import_Cost = S3_Grid_Import * Grid_Import_Price;
S3_Export_Rev  = S3_Grid_Export * Grid_Export_Price;
S3_PV_Cost     = S3_PV_Energy   * PV_Gen_Cost;
S3_Net_Cost    = S3_Import_Cost + S3_PV_Cost - S3_Export_Rev;

%% Annual projections
S1_Annual = S1_Net_Cost * 365;
S2_Annual = S2_Net_Cost * 365;
S3_Annual = S3_Net_Cost * 365;

%% Savings vs baseline
BESS_Daily_Saving  = S1_Net_Cost - S2_Net_Cost;
HESS_Daily_Saving  = S1_Net_Cost - S3_Net_Cost;
BESS_Annual_Saving = BESS_Daily_Saving * 365;
HESS_Annual_Saving = HESS_Daily_Saving * 365;

%% Economic Plot 1 — Daily cost breakdown
figure('Name','Economics 1 — Daily Cost Breakdown');
cost_data = [S1_Import_Cost S1_Export_Rev S1_Net_Cost;
             S2_Import_Cost S2_Export_Rev S2_Net_Cost;
             S3_Import_Cost S3_Export_Rev S3_Net_Cost];
b4 = bar(cost_data, 0.6);
b4(1).FaceColor = [0.8 0.3 0.3];
b4(2).FaceColor = [0.3 0.7 0.4];
b4(3).FaceColor = [0.2 0.4 0.8];
set(gca,'XTickLabel', scenarios);
ylabel('Cost / Revenue (USD)');
title('Daily Economic Analysis — All 3 Scenarios');
legend('Grid Import Cost','Export Revenue','Net Daily Cost', ...
    'Location','best');
grid on;

%% Economic Plot 2 — Annual savings
figure('Name','Economics 2 — Annual Savings vs Baseline');
savings = [0, BESS_Annual_Saving, HESS_Annual_Saving];
b5 = bar(savings, 0.5);
b5.FaceColor = 'flat';
b5.CData = clr;
set(gca,'XTickLabel', scenarios);
ylabel('Annual Savings vs No Storage (USD)');
title('Annual Cost Savings from Storage');
grid on;
for i = 1:3
    text(i, savings(i) + max(savings)*0.02, ...
        sprintf('$%.0f', savings(i)), ...
        'HorizontalAlignment','center','FontWeight','bold');
end

%% Economic Plot 3 — Annual net cost
figure('Name','Economics 3 — Annual Net Cost');
annual_costs = [S1_Annual, S2_Annual, S3_Annual];
b6 = bar(annual_costs, 0.5);
b6.FaceColor = 'flat';
b6.CData = clr;
set(gca,'XTickLabel', scenarios);
ylabel('Annual Net Cost (USD)');
title('Annual Net Energy Cost — All 3 Scenarios');
grid on;
for i = 1:3
    text(i, annual_costs(i) + max(annual_costs)*0.02, ...
        sprintf('$%.0f', annual_costs(i)), ...
        'HorizontalAlignment','center','FontWeight','bold');
end

fprintf('  Area 3 complete.\n\n');

%% ════════════════════════════════════════════════════════════════
%% FINAL SUMMARY TABLE
%% ════════════════════════════════════════════════════════════════
fprintf('================================================\n');
fprintf('       COMPREHENSIVE RESULTS SUMMARY\n');
fprintf('================================================\n\n');

fprintf('%-32s %12s %12s %12s\n', ...
    'Metric','No Storage','PV+BESS','PV+HESS');
fprintf('%s\n', repmat('-',1,70));
fprintf('%-32s %12.1f %12.1f %12.1f\n', ...
    'PV Energy (kWh)',        S1_PV_Energy,     S2_PV_Energy,     S3_PV_Energy);
fprintf('%-32s %12.1f %12.1f %12.1f\n', ...
    'Load Energy (kWh)',      S1_Load_Energy,   S2_Load_Energy,   S3_Load_Energy);
fprintf('%-32s %12.1f %12.1f %12.1f\n', ...
    'Grid Import (kWh)',      S1_Grid_Import,   S2_Grid_Import,   S3_Grid_Import);
fprintf('%-32s %12.1f %12.1f %12.1f\n', ...
    'Grid Export (kWh)',      S1_Grid_Export,   S2_Grid_Export,   S3_Grid_Export);
fprintf('%-32s %12.1f %12.1f %12.1f\n', ...
    'Renewable (%)',          S1_Renewable_Pct, S2_Renewable_Pct, S3_Renewable_Pct);
fprintf('%-32s %12.1f %12.1f %12.1f\n', ...
    'Grid Dependency (%)',    S1_Grid_Dep,      S2_Grid_Dep,      S3_Grid_Dep);
fprintf('%s\n', repmat('-',1,70));
fprintf('%-32s %12.2f %12.2f %12.2f\n', ...
    'Daily Net Cost (USD)',   S1_Net_Cost,      S2_Net_Cost,      S3_Net_Cost);
fprintf('%-32s %12.2f %12.2f %12.2f\n', ...
    'Annual Net Cost (USD)',  S1_Annual,        S2_Annual,        S3_Annual);
fprintf('%-32s %12s %12.2f %12.2f\n', ...
    'Annual Saving vs Base',  'Baseline', BESS_Annual_Saving, HESS_Annual_Saving);
fprintf('%s\n', repmat('-',1,70));
fprintf('%-32s %12s %12.1f %12.1f\n', ...
    'Battery Lifetime (yrs)', 'N/A', Years_EOL_BESS, Years_EOL_HESS);
fprintf('%-32s %12s %12.3f %12.3f\n', ...
    'Daily Cycles Used',      'N/A', Daily_Cycles_BESS, Daily_Cycles_HESS);
fprintf('\n');
fprintf('All comparison, degradation and economic plots generated.\n');
fprintf('Comprehensive analysis complete!\n');
