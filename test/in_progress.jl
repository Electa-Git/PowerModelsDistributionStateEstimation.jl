using PowerModelsDistribution, Ipopt
using DistributionTestCases, OpenDSSDirect
import Plots

PMD = PowerModelsDistribution
DTC = DistributionTestCases

data = PMD.parse_file(DTC.CASE_PATH["IEEE123"])

pmd_pf_res = PMD.run_mc_pf_lm(data, _PMs.ACPPowerModel, with_optimizer(Ipopt.Optimizer))
dss_pf_res = DTC.get_soldss_opendssdirect(DTC.CASE_PATH["IEEE123"]; tolerance=1e-006) #tolerance is the tolerance of openDSS convergence


δ_max = DTC.compare_dss_to_pmd( dss_pf_res, pmd_pf_res, data; vm_rtol = 1E-6, verbose = true, buses_compare_ll=["610"], )

vmin,vmax = DTC.get_vm_minmax( dss_pf_res, pmd_pf_res, data; buses_skip=[] )

Plots.plotly()
data_pmd = PMD.parse_file(DTC.CASE_PATH["IEEE123"])
coords = DTC.get_bus_coords(data_pmd)
DTC.draw_topology(data_pmd, coords)
