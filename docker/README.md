# cellbasedmodels docker

The dockerfile makes an image that contains a set of relevant packages for the use with CellBasedModels. A list can be seen in `environment.yaml`.

Constructed images are already deposited in [dsblab/cellbasedmodels](https://hub.docker.com/repository/docker/dsblab/cellbasedmodels), so there is not need of building the image except if you want to extend further capabilities.

# Running the image

## Interactive Shell

Start the container in interactive format.

```shell
docker run -it \
    --mount type=bind,source="$(pwd)",target=/home \
    dsblab/cellbasedmodels:v0.1.0 julia
```

## Script

To execute directly a bash script simply

```shell
docker run \
    --mount type=bind,source="$(pwd)",target=/home \
    dsblab/cellbasedmodels:v0.1.0 /bin/bash -c "<bash_script.sh>"
```

and a julia script

```shell
docker run \
    --mount type=bind,source="$(pwd)",target=/home \
    dsblab/cellbasedmodels:v0.1.0 /bin/bash -c "julia <julia_script.py>"
```

## Jupyter lab

If you want to work interactively with a jupyter notebook.

```shell
docker run -it \
    -p 8888:8888 \
    --mount type=bind,source="$(pwd)",target=/home \
    dsblab/cellbasedmodels:v0.1.0
```

You can then view the Jupyter Notebook by opening `http://localhost:8888` in your browser, or `http://<DOCKER-MACHINE-IP>:8888` if you are using a Docker.