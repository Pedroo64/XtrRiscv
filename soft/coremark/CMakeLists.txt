cmake_minimum_required (VERSION 3.16.3)
set(CMAKE_BUILD_TYPE DEBUG) # Set to RELEASE or DEBUG

set(ARCH "rv32imc")
set(ABI "ilp32")
set(MEMSIZE "32K")
set(SECTION_START "0K")
set(STACK_SIZE "2K")
set(HEAP_SIZE "2K")

set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/../scripts/toolchain_script.cmake")
set(LINKER_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/../scripts/linker.ld")

# You can change this to select your compiler
set(COMPILER_PREFIX "riscv64-unknown-elf-")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

project(coremark C ASM CXX)

if (DEFINED SIM_BUILD)
    if (NOT DEFINED ITERATIONS)
        set(ITERATIONS 10)
    endif()
    if (NOT DEFINED STOP_TIME)
        set(STOP_TIME 1000ms)
    endif ()
    set(FCPU 1000)
    add_compile_definitions(SIM_BUILD=${SIM_BUILD})
else ()
    if (NOT DEFINED ITERATIONS)
        set(ITERATIONS 1000)
    endif()
    if (NOT DEFINED FCPU)
        message(FATAL_ERROR "You must define set FCPU when running on hardware. Eg: cmake . -DFCPU=100000000 for 100MHz")
    endif()
endif()

add_compile_definitions(FLAGS_STR="${CMAKE_C_FLAGS}" ITERATIONS=${ITERATIONS} CLOCKS_PER_SEC=${FCPU} HAS_FLOAT)

include_directories(inc)
file(GLOB src
    src/*.c
    src/*.cpp
)

include_directories(../lib/inc)
file(GLOB lib
    ../lib/src/*.c
    ../lib/src/*.cpp
    ../lib/src/riscv/*.S
)

add_executable(${CMAKE_PROJECT_NAME} ${src} ${lib})

target_link_libraries(${CMAKE_PROJECT_NAME} c)
target_link_libraries(${CMAKE_PROJECT_NAME} gcc)

include(../scripts/targets.cmake)
