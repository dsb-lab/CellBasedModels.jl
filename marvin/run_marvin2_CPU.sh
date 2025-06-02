#!/bin/bash
#SBATCH --job-name=julia-notebook
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
##SBATCH --time=01:00:00
#SBATCH --output=notebook-%j.out
#SBATCH --error=notebook-%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=julia.vicens@upf.edu

echo "Inicio del script: $(date)"

# Cargar Python correcto para entorno virtual (por si hace falta activar algo)
module use /homes/aplic/noarch/modules/all
module load Python/3.11.5-GCCcore-13.2.0

# Activar Julia 1.8.5 local
export PATH="/homes/users/jvicens/julia/julia-1.10.3/bin:$PATH"
julia --version

# Activar entorno virtual con Jupyter funcional
# source ~/cellbasedmodels/bin/activate
which jupyter
jupyter --version

# Ejecutar el notebook
jupyter nbconvert --to notebook --execute ../proves/Bacteries_marvin.ipynb --output resultado_$SLURM_JOB_ID.ipynb

# Desactivar entorno
deactivate

echo "Fin del script: $(date)"
