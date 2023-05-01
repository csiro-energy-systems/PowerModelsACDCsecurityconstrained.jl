# PowerModelsACDCsecurityconstrained.jl


PowerModelsACDCsecurityconstrained.jl is a Julia/JuMP/PowerModels package for security-constrained optimal power flow in AC-DC grids.
Building upon the PowerModels architecture, the code is engineered to decouple security-constrained optimal power flow problem from the power network formulations for AC-DC grids.

**Installation**


```julia
Pkg.add("PowerModelsACDCsecurityconstrained")
```


**Core Problem Specifications**
* Security-constrained Optimal Power Flow with both point-to-point and meshed multi-terminal dc grid support


**Core Formulations**
* Nonlinear nonconvex formulation (NLP). All AC formulations of PowerModels, PowerModelsACDC, and PowerModelsSecurityConstrained are re-used.


Additional Features:
* A non-dominated contingency filtering algorithm.
* A post-contingency, short-term re-dispatch optimization.
* Modelling of the generator’s post-contingency droop-based frequency response.
* Modelling of the PV/PQ bus switching-based post-contingency voltage response of generators.
* Dead-band-based dc voltage-power droop control of HVDC converters. 




**Network Data Formats**
* MatACDC-style ".m" files (matpower ".m"-derived).
* Matpower-style ".m" files, including matpower's dcline extenstions.
* PTI ".raw" files, using PowerModels.jl parser



## Contributors

* Ghulam Mohy ud din (CSIRO)
* Rahmat Heidarihaei (CSIRO)
* Frederik Geth (GridQube)
* Hakan Ergun (KU Leuven / EnergyVille)

