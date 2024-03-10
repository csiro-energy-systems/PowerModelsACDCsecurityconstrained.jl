# PowerModelsACDCsecurityconstrained (PMACDCsc)


PMACDCsc is a Julia/JuMP package for steady-state security-constrained optimization problems for hybrid AC/DC grids. PMACDCsc extends [PowerModelsSecurityConstrained.jl](https://github.com/lanl-ansi/PowerModelsSecurityConstrained.jl) to the features of [PowerModelsACDC.jl](https://github.com/Electa-Git/PowerModelsACDC.jl). The code is engineered to address the problem specifications such as:

* Security-constrained optimal power flow (SCOPF); 
* Security-constrained unit commitment (SCUC);
* Post-preventive SCOPF curative re-dispatch;
* Contingency filtering (severity index (SI filter), and non-dominated contingency (NDC filter));
* Security-constrained transmisssion network expansion planning (SCTNEP);
* Optimal power and frequency control ancillary services (OPFCAS); and
* Marginal Loss Factor (MLF) calculation. 

Building upon the [PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl) and [PowerModelsACDC.jl](https://github.com/Electa-Git/PowerModelsACDC.jl) architecture, the code supports the formulations such as:

* ACPPowerModel; and 
* DCPPowerModel.

Moreover, the code supports the following netowk data formats: 

* Matpower ".m" files; and
* PTI ".raw" files (PSS(R)E v33 specification).


## Usage

Clone the package and add it to your julia environment using: 

```julia
] develop https://github.com/csiro-energy-systems/PowerModelsACDCsecurityconstrained.jl.git
```

Add all dependencies, such as, PowerModels, PowerModelsACDC, PowerModelsSecurityConstrained etc. using:

```julia
] add PowerModels
```

Make sure that your Julia registry is up to date. To detect and download the latest version of the packages use:

```julia
] update
```


## SCOPF implimentations

PMACDCsc provides several SCOPF formulations conforming to the ARPA-e GOC Challenge 1 specifications for hybrid AC/DC grids, which are given as follows.
 

Two-stage mathematical programming model (TSMP): complete base and contingency case models:

```julia
run_scopf_acdc_contingencies(data, scopf_formulation, filter_formulation, scopf_problem, scopf_solver, filter_solver, setting)
```
As an example, it can be used as:

```julia
result = PowerModelsACDCsecurityconstrained.run_scopf_acdc_contingencies(data, PowerModels.ACPPowerModel, PowerModels.ACPPowerModel, PowerModelsACDCsecurityconstrained.run_scopf, Ipopt.Optimizer, Ipopt.Optimizer, setting)
```

TSMP model: complete base and contingency case models with soft constraints and penalized slack variables:

```julia
run_scopf_acdc_contingencies(data, scopf_formulation, filter_formulation, run_scopf_soft, scopf_solver, filter_solver, setting)
```

TSMP model: complete base and contingency case models with soft constraints, penalized slack variables, and smooth approximated generator's frequency and voltage response, and AC/DC converter's P-Vdc droop control:

```julia
run_scopf_acdc_contingencies(data, scopf_formulation, filter_formulation, run_scopf_soft_smooth, scopf_solver, filter_solver, setting)
```

TSMP model: complete base and contingency case models with soft constraints, penalized slack variables, and mixed-integer based generator's frequency and voltage response, and AC/DC converter's P-Vdc droop control:

```julia
run_scopf_acdc_contingencies(data, scopf_formulation, filter_formulation, run_scopf_soft_minlp, minlp_scopf_solver, filter_solver, setting)
```

Decomposition based model conforming to the ARPA-e GOC Challenge 1 Benchmark heuristic developed in [PowerModelsSecurityConstrained.jl](https://github.com/lanl-ansi/PowerModelsSecurityConstrained.jl), which is extended to include AC/DC converter station and DC grid models. The contingency case branch flow constraints are enforced by PTDF and DCDF cuts and penalized based on a conservative linear
approximation of the formulation's specification.


```julia
run_scopf_acdc_cuts(data, scopf_formulation, filter_formulation, run_acdc_scopf_cuts, scopf_solver, filter_solver, setting)
```

The above mentioned decomposition based model with soft constraints and penalized slack variables:

```julia
run_scopf_acdc_cuts(data, scopf_formulation, filter_formulation, run_acdc_scopf_cuts_soft, scopf_solver, filter_solver, setting)
```


## Proof-of-concept studies

Several scripts are provided to showcase how effectively PMACDCsc solves the real-world research problems:

* The `scripts` directory provides differnt test case examples of SCOPF implimentations.
* The `src/nem` directory provides the AC/DC SCOPF huiristic for the Australian National Electricity Market (NEM). 
* The `src/nem` directory provides the AC/DC OPFCAS for the Australian NEM. 
* The `scripts` directory provides the MLF calculation huiristic for the Australian NEM.



## Citing PMACDCsc

If you find PMACDCsc useful in your work, we kindly request that you cite the following publication [PMACDCsc](https://ieeexplore.ieee.org/):
```
@inproceedings{PMACDCsc,
  author = {Mohy-ud-din, Ghulam and Heidari, Rahmat and Ergun, Hakan and Geth, Frederik},
  title = {AC-DC Security-Constrained Optimal Power Flow for the Australian National Electricity Market},
  booktitle = {2024 Power Systems Computation Conference (PSCC)},
  year = {2024},
  month = {June},
  pages = {1-10}, 
  doi = {10.XXXXX/PSCC.2024.XXXXXXX}
}
```


## Contributors

* Ghulam Mohy ud din (CSIRO): Main developer
* Mark-Colquhoun (CSIRO): OPFCAS problem and MLF calculation
* Rahmat Heidarihaei (CSIRO): Supervision and technical support
* Frederik Geth (GridQube): Advice and support on AC/DC OPF formulations
* Hakan Ergun (KU Leuven / EnergyVille): Advice and support on AC/DC OPF formulations


## License

This package is licensed under CSIRO Open Source Software Licence Agreement (variation of the BSD / MIT License). Copyright (c) 2022, Commonwealth Scientific and Industrial Research Organisation (CSIRO) ABN 41 687 119 230.