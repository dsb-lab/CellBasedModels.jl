#!/bin/bash
#SBATCH --job-name=j_gpu
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
##SBATCH --time=01:00:00
#SBATCH --output=notebook-gpu-%j.out
#SBATCH --error=notebook-gpu-%j.err
#SBATCH --gres=gpu:1
#SBATCH --partition=mr-06
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=julia.vicens@upf.edu

echo "Inicio: $(date)"
module use /homes/aplic/noarch/modules/all
module load Python/3.11.5-GCCcore-13.2.0
module load CUDA/12.1.1

export PATH="/homes/users/jvicens/julia/julia-1.10.3/bin:$PATH"
julia --version
nvidia-smi

jupyter nbconvert --to notebook --execute ../proves/Bacteries_overdamped.ipynb \
  --ExecutePreprocessor.timeout=-1 \
  --output resultado_gpu_$SLURM_JOB_ID.ipynb

echo "Fin: $(date)"
