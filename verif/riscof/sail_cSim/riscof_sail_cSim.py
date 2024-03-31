import os
import re
import shutil
import subprocess
import shlex
import logging
import random
import string
from string import Template
import distutils

import riscof.utils as utils
from riscof.pluginTemplate import pluginTemplate
import riscof.constants as constants
from riscv_isac.isac import isac

logger = logging.getLogger()

class sail_cSim(pluginTemplate):
    __model__ = "sail_c_simulator"

    # Ignore test list since RISCOF selects it even if the extension
    # is not enabled
    ignore_test_list = ['flh-align-01']

    def __init__(self, *args, **kwargs):
        sclass = super().__init__(*args, **kwargs)

        config = kwargs.get('config')
        if config is None:
            logger.error("Config node for sail_cSim missing.")
            raise SystemExit

        self.__docker       = bool(config['docker']) if 'docker' in config else False
        self.__riscv_prefix = config['riscv_prefix']
        self.__gcc          = f'{self.__riscv_prefix}gcc'
        self.__objdump      = f'{self.__riscv_prefix}objdump'
        self.__num_jobs     = str(config['jobs'] if 'jobs' in config else 1)
        self.__docker_img   = str(config['image']) if 'image' in config else 'riscv_compliance'
        self.__pluginpath   = os.path.abspath(config['pluginpath'])

        if not self.__docker:
            path = config['PATH'] if 'PATH' in config else ""
        else:
            path = "/usr/bin/"

        self.__sail_exe = {
                '32' : os.path.join(path,"riscv_sim_RV32"),
                '64' : os.path.join(path,"riscv_sim_RV64")
        }
        self.isa_spec = os.path.abspath(config['ispec']) if 'ispec' in config else ''
        self.platform_spec = os.path.abspath(config['pspec']) if 'ispec' in config else ''
        self.__make = config['make'] if 'make' in config else 'make'
        logger.debug("SAIL CSim plugin initialised using the following configuration.")
        for entry in config:
            logger.debug(entry + ' : ' + config[entry])
        return sclass

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.archtest_env = archtest_env
        self.__compile_cmd = \
            f'{self.__gcc} -march={{0}} -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles \
            -T {self.__pluginpath}/env/link.ld -I {self.__pluginpath}/env -I {archtest_env}'
        self.__objdump_cmd = f'{self.__objdump} -D {{0}} > {{2}}'

    def build(self, isa_yaml, platform_yaml):
        ispec = utils.load_yaml(isa_yaml)['hart0']
        self.xlen = ('64' if 64 in ispec['supported_xlen'] else '32')
        self.isa = 'rv' + self.xlen
        self.__compile_cmd = f'{self.__compile_cmd} -mabi={"lp64" if 64 in ispec["supported_xlen"] else "ilp32"}'
        if "I" in ispec["ISA"]:
            self.isa += 'i'
        if "M" in ispec["ISA"]:
            self.isa += 'm'
        if "C" in ispec["ISA"]:
            self.isa += 'c'

        if not self.__docker:
            if shutil.which(self.__objdump) is None:
                logger.error(self.__objdump + ": executable not found. Please check environment setup.")
                raise SystemExit
            if shutil.which(self.__gcc) is None:
                logger.error(self.__gcc + ": executable not found. Please check environment setup.")
                raise SystemExit
            if shutil.which(self.__sail_exe[self.xlen]) is None:
                logger.error(self.__sail_exe[self.xlen] + ": executable not found. Please check environment setup.")
                raise SystemExit
            if shutil.which(self.__make) is None:
                logger.error(self.__make + ": executable not found. Please check environment setup.")
                raise SystemExit
        else:
            logger.info(f"Starting docker image sail {self.__docker_img}")
            subprocess.run([f'docker run -it -d -v {self.work_dir}:/work --name sail {self.__docker_img} /bin/bash'], shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def runTests(self, testList,cgf_file=None):
        make = utils.makeUtil(makefilePath=os.path.join(self.work_dir, "Makefile." + self.name[:-1]))
        make.makeCommand = self.__make + ' -j' + self.__num_jobs
        for file in testList:
            testentry = testList[file]
            test = testentry['test_path']
            test_dir = testentry['work_dir']
            test_name = test.rsplit('/',1)[1][:-2]

            elf = 'ref.elf'
            for label in testentry['coverage_labels']:
                cov_str = f'-l {label}'
            else:
                cov_str = ''
            if cgf_file is not None:
                coverage_cmd = 'riscv_isac --verbose info coverage -d \
                        -t {0}.log --parser-name c_sail -o coverage.rpt  \
                        --sig-label begin_signature  end_signature \
                        --test-label rvtest_code_begin rvtest_code_end \
                        -e ref.elf -c {1} -x{2} {3};'.format(\
                        test_name, ' -c '.join(cgf_file), self.xlen, cov_str)
            else:
                coverage_cmd = ''
            execute = []
            sail_exe = f'{self.__sail_exe[self.xlen]} --test-signature=Reference-sail_c_simulator.signature {elf} > {test_name}.log 2>&1'
            if self.__docker:
                sail_exe = f'docker exec -i -w {test_dir.replace(self.work_dir,"/work")} sail {sail_exe}'
            execute.append(f'@cd {test_dir};')
            execute.append(f'{self.__compile_cmd.format(testentry["isa"].lower(), self.xlen)} {test} -o {elf} {" -D" + " -D".join(testentry["macros"])};')
            execute.append(f'{self.__objdump_cmd.format(elf, self.xlen, "ref.disass")};')
            if test_name in self.ignore_test_list:
                execute.append(f'touch Reference-sail_c_simulator.signature')
            else:
                execute.append(f'{sail_exe};')
            if not self.__docker:
                execute.append(coverage_cmd)
            make.add_target(' '.join(execute),tname=test_name)
        make.execute_all(self.work_dir)

    def __del__(self):
        if self.__docker:
            logger.info(f"Stopping docker image sail {self.__docker_img}")
            subprocess.run(['docker stop sail; docker rm sail;'], shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)