cmake_minimum_required (VERSION 3.16.3)
set(CMAKE_BUILD_TYPE DEBUG) # Set to RELEASE or DEBUG

set(ARCH "rv32i")
set(ABI "ilp32")
set(MEMSIZE "32K")
set(F_CPU "100e6")
set(SECTION_START "0K")
set(STACK_SIZE "2K")
set(HEAP_SIZE "2K")

# Clone software repository that contains all drivers (https://github.com/RiscDuinoV/Software)
# Add to CMAKE_TOOLCHAIN_PATH the path to toolchain script (https://github.com/RiscDuinoV/Software/blob/dev/tools/cmake/Toolchain_Script.cmake)
set(CMAKE_TOOLCHAIN_PATH "PATH_TO_TOOLCHAIN_SCRIPT_FOLDER")
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_TOOLCHAIN_PATH}/Toolchain_Script.cmake")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

project(test.elf C ASM CXX)
include("${CMAKE_TOOLCHAIN_PATH}/Options.cmake")
list(FILTER xtr_soc_src EXCLUDE REGEX interrupt_controller.c)
include_directories(inc)
file(GLOB src
    src/*.S src/*.c src/*.cpp
)
add_executable(${CMAKE_PROJECT_NAME} ${src} ${xtr_soc_src})  

# Important
target_link_libraries(${CMAKE_PROJECT_NAME} c)
target_link_libraries(${CMAKE_PROJECT_NAME} gcc)
