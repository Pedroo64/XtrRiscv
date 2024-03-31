import os
import re
import shutil
import subprocess
import shlex
import logging
import random
import string
from string import Template
import sys

import riscof.utils as utils
import riscof.constants as constants
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

class xtrriscv(pluginTemplate):
    __model__ = "xtrriscv"

    # Ignore test list since RISCOF selects it even if the extension
    # is not enabled
    ignore_test_list = ['flh-align-01']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.__config = kwargs.get('config')
        self.__riscv_prefix: str = self.__config['riscv_prefix']
        self.__gcc     = f'{self.__riscv_prefix}gcc'
        self.__objdump = f'{self.__riscv_prefix}objdump'
        self.__objcopy = f'{self.__riscv_prefix}objcopy'
        self.__hexdump = f'hexdump'

        self.__cpu_config = {
            'execute_bypass': False,
            'memory_bypass': False,
            'writeback_bypass': False,
            'regfile_bypass': False,
            'full_barrel_shifter': False,
            'shifter_early_injection': False,
            'extension_zicsr': False,
            'extension_m': False,
            'extension_c': False,
        }

        if self.__config is None:
            print("Please enter input file paths in configuration.")
            raise SystemExit(1)

        if 'ghdl' in self.__config.keys():
            self.__dut_exe = f'make -C {kwargs["config_dir"]}/{self.__config["ghdl"]} run_only INIT_FILE={{0}}/{{1}}.mem OUTPUT_FILE={{0}}/DUT-xtrriscv.signature STOP_TIME=15ms'
        elif 'modelsim' in self.__config.keys():
            self.__dut_exe = f'make -C {kwargs["config_dir"]}/{self.__config["modelsim"]} run INIT_FILE={{0}}/{{1}}.mem OUTPUT_FILE={{0}}/DUT-xtrriscv.signature STOP_TIME=15ms SPEED=1 GUI=0'
        else:
            print('DUT must have a simulator platform to run.')
            raise SystemExit(1)

        self.__num_jobs = str(self.__config['jobs'] if 'jobs' in self.__config else 1)
        self.__pluginpath=os.path.abspath(self.__config['pluginpath'])
        self.isa_spec = os.path.abspath(self.__config['ispec'])
        self.platform_spec = os.path.abspath(self.__config['pspec'])
        if 'target_run' in self.__config and self.__config['target_run']=='0':
            self.target_run = False
        else:
            self.target_run = True

    def initialise(self, suite, work_dir, archtest_env):
        self.__work_dir = work_dir
        self.__compile_cmd = self.__gcc + ' -march={0} \
            -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g\
            -T ' + self.__pluginpath + '/env/link.ld\
            -I ' + self.__pluginpath + '/env/\
            -I ' + archtest_env + ' {2} -o {3} {4}'

    def build(self, isa_yaml, platform_yaml):
        ispec = utils.load_yaml(isa_yaml)['hart0']
        self.xlen = ('64' if 64 in ispec['supported_xlen'] else '32')
        self.isa = 'rv' + self.xlen
        if "I" in ispec["ISA"]:
            self.isa += 'i'
            self.__cpu_config['extension_zicsr'] = True
        if "M" in ispec["ISA"]:
            self.isa += 'm'
            self.__cpu_config['extension_m'] = True
        if "C" in ispec["ISA"]:
            self.isa += 'c'
            self.__cpu_config['extension_c'] = True

        self.__compile_cmd = self.__compile_cmd+' -mabi='+('lp64 ' if 64 in ispec['supported_xlen'] else 'ilp32 ')

    def runTests(self, testList):
        for key in self.__cpu_config:
            if key in self.__config.keys():
                self.__cpu_config[key] = self.__config[key]
            self.__dut_exe += f' {key.upper()}={str(self.__cpu_config[key]).upper()}'

        if os.path.exists(self.__work_dir+ "/Makefile." + self.name[:-1]):
                os.remove(self.__work_dir+ "/Makefile." + self.name[:-1])
        make = utils.makeUtil(makefilePath=os.path.join(self.__work_dir, "Makefile." + self.name[:-1]))
        make.makeCommand = 'make -k -j' + self.__num_jobs
        for testname in testList:
            testentry = testList[testname]
            test = testentry['test_path']
            test_dir = testentry['work_dir']
            test_name = test.rsplit('/',1)[1][:-2]
            elf = f'{test_name}.elf'
            compile_macros= ' -D' + " -D".join(testentry['macros'])
            execute = []
            execute.append(f'@cd {testentry["work_dir"]};')
            execute.append(f'{self.__compile_cmd.format(testentry["isa"].lower(), 64, test, elf, compile_macros)};')
            execute.append(f'{self.__objdump} {elf} --source > {test_name}.debug;')
            execute.append(f'{self.__objcopy} -O binary {elf} {test_name}.bin;')
            execute.append(f'cat {test_name}.bin | {self.__hexdump} -v -e \'"%08x\\n"\' > {test_name}.mem;')
            if test_name in self.ignore_test_list:
                execute.append(f'touch DUT-xtrriscv.signature')
            else:
                execute.append(f'{self.__dut_exe.format(test_dir, test_name)};')
            make.add_target(' '.join(execute), tname=test_name)

        if self.target_run:
            make.execute_all(self.__work_dir)

        if not self.target_run:
            raise SystemExit(0)
