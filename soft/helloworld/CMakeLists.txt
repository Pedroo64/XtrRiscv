cmake_minimum_required (VERSION 3.16.3)
set(CMAKE_BUILD_TYPE DEBUG) # Set to RELEASE or DEBUG

set(ARCH "rv32im")
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

project(helloworld C ASM CXX)

# Remove this if targeting hardware
add_compile_definitions(SIM_BUILD)

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
