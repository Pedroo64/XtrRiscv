set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          riscv)

# Without that flag CMake is not able to pass test compilation check
set(CMAKE_TRY_COMPILE_TARGET_TYPE   STATIC_LIBRARY)

if(NOT DEFINED COMPILER_PREFIX)
    set(COMPILER_PREFIX "riscv64-unknown-elf-")
endif()

# Specify the system library path
set(COMPILER_LIBRARY_PATH "${CMAKE_CURRENT_LIST_DIR}/../..")

set(LNK_FILE "linker_script.ld")

set(CMAKE_AR                        ${COMPILER_PREFIX}ar)
set(CMAKE_ASM_COMPILER              ${COMPILER_PREFIX}gcc)
set(CMAKE_C_COMPILER                ${COMPILER_PREFIX}gcc)
set(CMAKE_CXX_COMPILER              ${COMPILER_PREFIX}g++)
set(CMAKE_LINKER                    ${COMPILER_PREFIX}ld)
set(CMAKE_OBJCOPY                   ${COMPILER_PREFIX}objcopy CACHE INTERNAL "")
set(CMAKE_RANLIB                    ${COMPILER_PREFIX}ranlib CACHE INTERNAL "")
set(CMAKE_SIZE                      ${COMPILER_PREFIX}size CACHE INTERNAL "")
set(CMAKE_STRIP                     ${COMPILER_PREFIX}strip CACHE INTERNAL "")
set(CMAKE_DEBUG_COMPILER            ${COMPILER_PREFIX}gdb)
set(CMAKE_OBJDUMP                   ${COMPILER_PREFIX}objdump)
set(CMAKE_DEBUG_COMPILER_ENV_VAR    "")
set(FLAGS "-march=${ARCH} -mabi=${ABI} -fpeel-loops -ftree-ter -ffreestanding -ffunction-sections -fdata-sections -Wall")
set(CMAKE_ASM_FLAGS                 "${FLAGS}" CACHE INTERNAL "")
set(CMAKE_C_FLAGS                   "${FLAGS}" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS                 "${FLAGS} -fno-rtti -fno-exceptions -fpermissive" CACHE INTERNAL "")

set(CMAKE_C_FLAGS_DEBUG             "-Os -g" CACHE INTERNAL "")
set(CMAKE_C_FLAGS_RELEASE           "-Os -DNDEBUG" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS_DEBUG           "${CMAKE_C_FLAGS_DEBUG}" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS_RELEASE         "${CMAKE_C_FLAGS_RELEASE}" CACHE INTERNAL "")

# CMAKE_LINK
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CMAKE_EXE_LINKER_FLAGS "-mcmodel=medany -T${LINKER_SCRIPT} -nostartfiles -nostdlib -nodefaultlibs --specs=nano.specs --specs=nosys.specs -static -Xlinker --gc-sections -Xlinker --defsym=MEMSIZE=${MEMSIZE} -Xlinker --defsym=SECTION_START=${SECTION_START} -Xlinker --defsym=STACK_SIZE=${STACK_SIZE} -Xlinker --defsym=HEAP_SIZE=${HEAP_SIZE} -nostartfiles -nostdlib -nodefaultlibs")
