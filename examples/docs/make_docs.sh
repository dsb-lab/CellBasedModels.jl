#!/bin/bash

jupyter-nbconvert ../Usage_intro.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Usage_Agent.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Usage_Community.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Usage_Fitting.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Patterning.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Development.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Aggregation.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Bacteries.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Chemotaxis.ipynb --to markdown --output-dir="../../docs/src"
python addstring.py