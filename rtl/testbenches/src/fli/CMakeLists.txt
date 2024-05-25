cmake_minimum_required(VERSION 3.0)

# set(CMAKE_C_COMPILER "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.39.33519/bin/Hostx64/x64/cl.exe")

project(fli)

# set(CMAKE_C_COMPILER i686-w64-mingw32-gcc)

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

set(MTI_PATH "C:/intelFPGA/22.1std/questa_fse")
# set(MTI_PATH "/mnt/c/intelFPGA/22.1std/questa_fse")

add_library(${PROJECT_NAME} SHARED ${src} ${utils})

target_include_directories(${PROJECT_NAME} PUBLIC ${MTI_PATH}/include)

if (WIN32)
target_link_directories(${PROJECT_NAME} PUBLIC ${MTI_PATH}/win64)
target_link_libraries(${PROJECT_NAME} wsock32 ws2_32)
else ()
target_link_directories(${PROJECT_NAME} PUBLIC ${MTI_PATH}/bin)
endif()

target_link_libraries(${PROJECT_NAME} mtipli)

