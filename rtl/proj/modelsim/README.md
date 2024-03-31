# Modelsim
## Requirements
- [Modelsim/Questa](https://www.intel.com/content/www/us/en/collections/products/fpga/software/downloads.html?edition=lite&s=Newest)
- make
```bash
$ apt-get install make
```

## Compiling the testbench
```bash
$ make compile
```

## Running the testbench
To run the testbench run the following command:
```bash
$ make run INIT_FILE=PATH_TO_MEMFILE
```

This will run the testbench until it hits the assert to finish the simulation. To trigger the finish, the CPU must write `0xCAFECAFE` at address `0x80020000`.