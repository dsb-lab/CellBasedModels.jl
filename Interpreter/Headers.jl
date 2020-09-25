const AllHeadersParams = [
"SpatialGlobalParams:",
"SpatialLocalParams:",
"SpatialVariables:",
"SpatialRandomVariables:",

"ChemicalGlobalParams:",
"ChemicalLocalParams:",
"ChemicalVariables:",
"ChemicalRandomVariables:",

"GrowthGlobalParams:",
"GrowthLocalParams:",
"GrowthVariables:",
"GrowthRandomVariables:",
]

const AllHeadersEqs = [
"Dynamics:", 
"SplitProcess:"
]

const SpatialHeadersParams = 
["SpatialGlobalParams:",
 "SpatialLocalParams:",
 "SpatialVariables:"
]
const SpatialHeadersRandom = ["SpatialRandomVariables:"]
const SpatialHeadersCompulsory = ["SpatialVariables:", "Dynamics:"]

const ChemicalHeadersParams = 
["ChemicalGlobalParams:",
"ChemicalLocalParams:",
"ChemicalVariables:",
]
const ChemicalHeadersRandom = ["ChemicalRandomVariables:"]
const ChemicalHeadersCompulsory = ["ChemicalVariables:", "Dynamics:"]

const GrowthHeadersParams = 
["GrowthGlobalParams:",
 "GrowthLocalParams:",
 "GrowthVariables:",
]
const GrowthHeadersRandom = ["GrowthRandomVariables:"]
const GrowthHeadersCompulsory = [ "GrowthVariables:", "Dynamics:", "SplitProcess:"]