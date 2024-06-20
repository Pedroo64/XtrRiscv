cmake_minimum_required(VERSION 3.0)

project(vpi)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

include_directories(../utils/inc)

file(GLOB src 
    src/*.cpp
)

file(GLOB utils
    ../utils/src/*.cpp
)

set(VPI_PATH "/opt/ghdl/include/ghdl")

add_library(${PROJECT_NAME} SHARED ${src} ${utils})

target_include_directories(${PROJECT_NAME} PUBLIC ${VPI_PATH})
