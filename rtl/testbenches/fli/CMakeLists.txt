cmake_minimum_required(VERSION 3.0)

project(fli)

add_compile_options(-D_WIN32_WINNT=0x0A00)

file(GLOB src
    src/tcp_server/*.cpp
    src/*.c
    src/*.cpp)

add_library(${PROJECT_NAME} SHARED ${src})

target_include_directories(${PROJECT_NAME} PUBLIC ${MTI_PATH}/include)


target_link_directories(${PROJECT_NAME} PUBLIC ${MTI_PATH}/win64)
target_link_libraries(${PROJECT_NAME} mtipli)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

target_link_libraries(${PROJECT_NAME} wsock32 ws2_32)