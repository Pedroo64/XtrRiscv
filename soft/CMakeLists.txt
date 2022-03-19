cmake_minimum_required (VERSION 3.0)
set(CMAKE_BUILD_TYPE DEBUG) # Set to RELEASE or DEBUG

set(ARCH "rv32i")
set(ABI "ilp32")
set(MEMSIZE "16K")
set(F_CPU "48e6")
set(SECTION_START "0K")
set(STACK_SIZE "2K")
set(HEAP_SIZE "2K")

set(TOOLCHAIN_PATH "/mnt/c/opt/compilers/riscv/sifive/ubuntu")
# set(TOOLCHAIN_PATH "C:/Users/Pedro/Documents/Compilers/RISCV/Windows")
set(CMAKE_TOOLCHAIN_PATH "cmake_tools")
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_TOOLCHAIN_PATH}/toolchain.cmake")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

project(test.elf C ASM CXX)
include("${CMAKE_TOOLCHAIN_PATH}/targets.cmake")
include_directories(inc)
set(src
    src/main.S src/main.c
)
add_executable(${CMAKE_PROJECT_NAME} ${src})  

# Important
target_link_libraries(${CMAKE_PROJECT_NAME} c)
target_link_libraries(${CMAKE_PROJECT_NAME} gcc)
