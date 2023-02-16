# Introduction

The basic structure of an agent-based simulation model is:

 1. Definition of a model with its evolution rules.
 2. Initialization of a community of agents to be evolved.
 3. Evolution of agents during some iterations and storage of the simulation results.
 4. Posterior analysis of the results.

We will cover the different parts of a AgentBasedModels.jl from how to define models to optimization of the models.

First, we will need to upload the package.


```python
using AgentBasedModels
```

## Basic Structures of the Package

The package works around the two main structures:

 - `Agent`: is the structure that contains all the information of the parameters and rules of the agents.
 - `Community`: is the structure that containts a realization of a set of agents that have the parameters and evolution rules defined by an `Agent`. The Community structure will be initialized and then evolved using the rules defined in the Agent structure.
