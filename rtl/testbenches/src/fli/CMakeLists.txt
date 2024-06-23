cmake_minimum_required(VERSION 3.0)

project(fli)

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

if (NOT DEFINED MTI_PATH)
    message(FATAL_ERROR "You must set the variable MTI_PATH to the path of Questa/Modelsim installation")
endif ()


add_library(${PROJECT_NAME} SHARED ${src} ${utils})

target_include_directories(${PROJECT_NAME} PUBLIC ${MTI_PATH}/include)

if (WIN32)
target_link_directories(${PROJECT_NAME} PUBLIC ${MTI_PATH}/win64)
target_link_libraries(${PROJECT_NAME} wsock32 ws2_32)
else ()
target_link_directories(${PROJECT_NAME} PUBLIC ${MTI_PATH}/bin)
endif()

target_link_libraries(${PROJECT_NAME} mtipli)

