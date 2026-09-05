%% HESS_EMS.m
% Hybrid Energy Storage System Energy Management
% Controls Battery + Supercapacitor + Flywheel together
% Priority: SuperCap first → Flywheel second → Battery last
%
% Inputs:
%   Power_Error  - PV minus Load at each step (W)
%   SOC_bat      - Battery SOC at this step (fraction)
%   V_sc         - Supercapacitor voltage at this step (V)
%   Speed_fw     - Flywheel speed at this step (RPM)
%   Battery      - Battery parameter struct
%   SuperCap     - Supercapacitor parameter struct
%   Flywheel     - Flywheel parameter struct
%
% Outputs:
%   P_bat  - Power command for battery (W)
%   P_sc   - Power command for supercapacitor (W)
%   P_fw   - Power command for flywheel (W)
%   P_grid - Power needed from grid (W)

function [P_bat, P_sc, P_fw, P_grid] = HESS_EMS(...
    Power_Error, ...
    SOC_bat, ...
    V_sc, ...
    Speed_fw, ...
    Battery, ...
    SuperCap, ...
    Flywheel)

%% Initialise all outputs to zero
P_bat  = 0;
P_sc   = 0;
P_fw   = 0;
P_grid = 0;

%% Remaining power to be handled
Remaining = Power_Error;

%% ── SUPERCAPACITOR first (fastest response) ──────────────────────
if Remaining > 0
    % Surplus PV — charge supercapacitor if not full
    if V_sc < SuperCap.Voltage_max
        P_sc      = min(Remaining, SuperCap.Max_Power);
        Remaining = Remaining - P_sc;
    end
elseif Remaining < 0
    % Deficit — discharge supercapacitor if not empty
    if V_sc > SuperCap.Voltage_min
        P_sc      = max(Remaining, -SuperCap.Max_Power);
        Remaining = Remaining - P_sc;
    end
end

%% ── FLYWHEEL second (medium response) ───────────────────────────
if Remaining > 0
    % Surplus — charge flywheel if not at max speed
    if Speed_fw < Flywheel.Speed_max
        P_fw      = min(Remaining, Flywheel.Max_Power);
        Remaining = Remaining - P_fw;
    end
elseif Remaining < 0
    % Deficit — discharge flywheel if above min speed
    if Speed_fw > Flywheel.Speed_min
        P_fw      = max(Remaining, -Flywheel.Max_Power);
        Remaining = Remaining - P_fw;
    end
end

%% ── BATTERY last (slow but large capacity) ───────────────────────
if Remaining > 0
    % Surplus — charge battery if not full
    if SOC_bat < Battery.SOC_max
        P_bat     = min(Remaining, Battery.Max_charge_power);
        Remaining = Remaining - P_bat;
    end
elseif Remaining < 0
    % Deficit — discharge battery if not empty
    if SOC_bat > Battery.SOC_min
        P_bat     = max(Remaining, -Battery.Max_discharge_power);
        Remaining = Remaining - P_bat;
    end
end

%% ── GRID covers whatever remains ────────────────────────────────
% Positive grid = import (grid supplies load)
% Negative grid = export (excess sent to grid)
P_grid = -Remaining;

end
