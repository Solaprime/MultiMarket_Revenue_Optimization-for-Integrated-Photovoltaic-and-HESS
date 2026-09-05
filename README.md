# Multi-Market Revenue Optimization for Integrated Photovoltaic and Hybrid Energy Storage Systems

Individual contribution focus: **battery degradation reduction via Hybrid Energy Storage Systems (HESS)**, as part of a wider group project on multi-market PV+HESS revenue optimization. Final-year undergraduate project, Department of Electrical and Electronics Engineering, University of Lagos.

Full written report chapters (methodology, results, and discussion) are the primary deliverable; this repository contains the supporting MATLAB/Octave source code, per the project supervisor's guidance that code should be version-controlled and linked, but is secondary to the report itself.

## Project Development History

This project was originally developed and verified against a **simplified single-bus grid representation** (Objectives 1 and 2), sufficient to test each storage technology's behavior in isolation and establish a PV baseline at residential (kW) scale.

Following supervisor guidance, Objectives 3 and 4 were then adapted to run on the **IEEE 14-bus standard test system** instead of the simplified grid, using MATPOWER for Optimal Power Flow (OPF) integration. This required re-scaling PV, load, and storage parameters from the kW range used in Objective 2 up to the MW range appropriate to the IEEE 14-bus network's generator capacities.

During this transition, several intermediate parameter scales (including a 150 MW PV / 500 MWh battery test configuration) were used purely to verify that the OPF integration correctly registered a visible change in generator dispatch when PV was injected at Bus 2. **These exploratory scripts are kept in this repository for transparency and development history, but they are not the basis for any result reported in the written report.**

## Which Scripts Are Canonical (Used for Reported Results)

| Objective | Canonical script(s) | Notes |
|---|---|---|
| 1 — Storage models | `01_Core_Models/*.m` | Battery, supercapacitor, flywheel models and degradation function |
| 2 — PV baseline | `Objective_2_Grid_Baseline/Main_PV_Grid_Simulation.m` + `03_System_Simulation/Objective2_PVSimulation.slx` | Script-based and Simulink implementations |
| 3 — PV + BESS on IEEE 14-bus | `Objective_3_Grid_Bess/Test_Objective3_Foundation.m` (dispatch verification) and `Objective_3_Grid_Bess/IEEE14_PV_Injection.m` (OPF integration) | Uses `Parameters_BESS.m` at its original 15 MW / 10 MWh scale |
| 4 — PV + HESS comparison | **`ProjectComaprisonResult/Project_Comparison_Final.m`** | The single source of truth for all Chapter 4 results (no-storage / BESS / HESS comparison, degradation, economics) |

## Exploratory / Superseded Scripts (Not Used for Reported Results)

The following files remain in the repository as development history but use a different, non-literature-grounded parameter scale and **should not be used to reproduce the numbers in the written report**:

- `Objective_3_Grid_Bess/IEEE14_PV_Injection_OPF_Fixed.m` — 150 MW PV / 50 MWh battery test variant
- `Objective_4_PV_HESS/Project_Comparison_Analysis.m` — earlier draft, superseded by `ProjectComaprisonResult/Project_Comparison_Final.m`

This distinction, and the reasoning behind it, is documented in the written report at **Chapter 3, Section 3.10.6 ("Documented Scope Decision: Analytical Comparison vs. OPF Integration")**.

## Requirements

- MATLAB (developed/tested) or GNU Octave with the `gnuplot` graphics toolkit (verification environment)
- [MATPOWER](https://matpower.org/) for Objective 3/4 OPF integration (`case14` test system)

## Repository Structure

```
01_Core_Models/            Objective 1: storage technology models
Objective_2_Grid_Baseline/ Objective 2: PV baseline (script-based)
03_System_Simulation/      Objective 2: PV baseline (Simulink/Simscape)
Objective_3_Grid_Bess/     Objective 3: PV + BESS, IEEE 14-bus OPF
Objective_4_PV_HESS/       Objective 4: PV + HESS
ProjectComaprisonResult/   Canonical Objective 3 vs 4 comparison — source of all Chapter 4 numbers
```
