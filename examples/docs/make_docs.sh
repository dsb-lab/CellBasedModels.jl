#!/bin/bash

jupyter-nbconvert ../Usage_intro.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Usage_Agent.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Usage_Community.ipynb --to markdown --output-dir="../../docs/src"
jupyter-nbconvert ../Usage_Fitting.ipynb --to markdown --output-dir="../../docs/src"
python addstring.py