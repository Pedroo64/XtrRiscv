# RISCOF
## Requirements
- Python >= 3.6
- RISCOF python module
- [GHDL](https://ghdl.github.io/ghdl/development/building/index.html)
- [Docker](https://www.docker.com/products/docker-desktop)
- [RISC-V Sail Model](https://github.com/riscv/sail-riscv)

```
$ apt install python3
$ python3 -m pip install riscof
```

Make sure that python is greater that 3.6
```
$ python3 --version
Python 3.6.0
```

Check that RISCOF is successfully installed
```
$ riscof --version
RISC-V Architectural Test Framework., version 1.25.3
```

### GHDL
For better compatibility do not use GHDL from the distro repositories. Build GHDL from sources [GHDL](https://ghdl.github.io/ghdl/development/building/index.html).

### RISC-V Sail Model
In this repository, the sail model is launched with docker. First install [docker](https://www.docker.com/products/docker-desktop). After installing [docker](https://www.docker.com/products/docker-desktop), download the RISC-V Sail Model docker image.

If you don't want to use docker, remove `docker` from `config.ini`.
In this case, you must have the sail model installed.
```
$ docker pull registry.gitlab.com/incoresemi/docker-images/compliance
```

## Run riscof test suite
To run the riscof test suite:
```
$ riscof run --config=config.ini --suite=../../vendor/riscv-arch-test/riscv-test-suite/ --env=../../vendor/riscv-arch-test/riscv-test-suite/env --no-browser
```
