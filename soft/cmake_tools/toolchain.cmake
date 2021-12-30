set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          riscv)

if(WIN32)
    set(WIN_EXE ".exe")
    set(DIR_NAME "Windows")
else()
    set(DIR_NAME "Linux-x86_64")
endif()

# Without that flag CMake is not able to pass test compilation check
set(CMAKE_TRY_COMPILE_TARGET_TYPE   STATIC_LIBRARY)

set(TOOLCHAIN_PREFIX "riscv64-unknown-elf-")

# Specify the system library path
set(COMPILER_LIBRARY_PATH "${CMAKE_CURRENT_LIST_DIR}/../..")

set(LNK_FILE "linker_script.ld")

set(CMAKE_AR                        ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}ar${WIN_EXE})
set(CMAKE_ASM_COMPILER              ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}gcc${WIN_EXE})
set(CMAKE_C_COMPILER                ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}gcc${WIN_EXE})
set(CMAKE_CXX_COMPILER              ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}g++${WIN_EXE})
set(CMAKE_LINKER                    ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}ld${WIN_EXE})
set(CMAKE_OBJCOPY                   ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}objcopy${WIN_EXE} CACHE INTERNAL "")
set(CMAKE_RANLIB                    ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}ranlib${WIN_EXE} CACHE INTERNAL "")
set(CMAKE_SIZE                      ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}size${WIN_EXE} CACHE INTERNAL "")
set(CMAKE_STRIP                     ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}strip${WIN_EXE} CACHE INTERNAL "")
set(CMAKE_DEBUG_COMPILER            ${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}gdb${WIN_EXE})
set(CMAKE_DEBUG_COMPILER_ENV_VAR    "")
set(FLAGS "-march=${ARCH} -mabi=${ABI} -DF_CPU=${F_CPU} -fpeel-loops -ftree-ter -ffreestanding -ffunction-sections -fdata-sections -Wall")
set(CMAKE_ASM_FLAGS                 "${FLAGS} ${CMAKE_ASM_FLAGS}" CACHE INTERNAL "")
set(CMAKE_C_FLAGS                   "${FLAGS} ${CMAKE_C_FLAGS}" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS                 "${FLAGS} -fno-rtti -fno-exceptions -fpermissive ${CMAKE_CXX_FLAGS}" CACHE INTERNAL "")

set(CMAKE_C_FLAGS_DEBUG             "-Os -g" CACHE INTERNAL "")
set(CMAKE_C_FLAGS_RELEASE           "-Os -DNDEBUG" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS_DEBUG           "${CMAKE_C_FLAGS_DEBUG}" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS_RELEASE         "${CMAKE_C_FLAGS_RELEASE}" CACHE INTERNAL "")

# CMAKE_LINK
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CMAKE_EXE_LINKER_FLAGS "-mcmodel=medany -Tcmake_tools/${LNK_FILE} -nostartfiles -nostdlib -nodefaultlibs --specs=nano.specs --specs=nosys.specs -static -Xlinker --gc-sections -Xlinker --defsym=MEMSIZE=${MEMSIZE} -Xlinker --defsym=SECTION_START=${SECTION_START} -Xlinker --defsym=STACK_SIZE=${STACK_SIZE} -Xlinker --defsym=HEAP_SIZE=${HEAP_SIZE} -nostartfiles -nostdlib -nodefaultlibs")