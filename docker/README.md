# cellbasedmodels docker

The dockerfile makes an image that contains a set of relevant packages for the use with CellBasedModels. A list can be seen in `environment.yaml`.

Constructed images are already deposited in [https://hub.docker.com/r/dsblab/cellbasedmodels](https://hub.docker.com/r/dsblab/cellbasedmodels), so there is not need of building the image except if you want to extend further capabilities.

# Running the image

> **NOTE Multithreading** 
> Docker images are by default exposed to all the threads but you have to provide the number of threads to the execution yu have to define the variable `JULIA_NUM_THREADS` inside the docker as shown in the examples below. More information can be seen in the [documentation](https://docs.julialang.org/en/v1/manual/multi-threading/).


## Interactive Shell

Start the container in interactive format.

```shell
docker run -it --rm \
    --mount type=bind,source="$(pwd)",target=/home \
    dsblab/cellbasedmodels:v0.1.0 julia --threads 4
```

## Script

To execute directly a bash script simply

```shell
docker run --rm \
    --mount type=bind,source="$(pwd)",target=/home \
    dsblab/cellbasedmodels:v0.1.0 /bin/bash -c "<bash_script.sh>"
```

and a julia script

```shell
docker run --rm \
    --mount type=bind,source="$(pwd)",target=/home \
    dsblab/cellbasedmodels:v0.1.0 /bin/bash -c "export JULIA_NUM_THREADS=4; julia <julia_script.py>"
```

## Jupyter lab

If you want to work interactively with a jupyter notebook.

```shell
docker run -it --rm \
    -p 8888:8888 \
    --mount type=bind,source="$(pwd)",target=/home \
    dsblab/cellbasedmodels:v0.1.0 /bin/bash -c "export JULIA_NUM_THREADS=4; jupyter lab --allow-root --ip 0.0.0.0"
```

# Comments on docker flags

There are many flags for dockers. In here I briefly resume some of the ones used in the examples above.

 - `-it`: Says the docker you are going to use it in interactive mode.
 - `--rm`: Remove the image once finished the job.
 - `-p`: Which port to show the connection
 - `-mount type=X,...`: Mount the folder so its content is accessible inside the docker. 

You can then view the Jupyter Notebook by opening `http://localhost:8888` in your browser, or `http://<DOCKER-MACHINE-IP>:8888` if you are using a Docker.