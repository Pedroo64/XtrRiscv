# Specify the program tool
#set(PROGRAM_TOOL_PATH "/mnt/c/Users/Pedro/Documents/Dev/Tss/XtrRiscv/soft/HAL/tools/Programmer")
set(PROGRAM_TOOL_PATH "/mnt/e/Dev/XtrRiscv-VexRiscv/soft/HAL/tools/Programmer")
set(PROGRAM_TOOL "${PROGRAM_TOOL_PATH}/${DIR_NAME}/Programmer${WIN_EXE}")
# include("${CMAKE_CURRENT_LIST_DIR}/../../system/src/CMakeLists.txt")
# include("${CMAKE_CURRENT_LIST_DIR}/../../cores/riscduinov/CMakeLists.txt")
# if(NOT ${USE_SYSTEM_STATIC_LIBRARY})
#     message("USE_SYSTEM_STATIC_LIBRARY = ${USE_SYSTEM_STATIC_LIBRARY}")
#     include("${CMAKE_CURRENT_LIST_DIR}/../../Hardware/software/system/src/CMakeLists.txt")
# endif()

add_custom_command(OUTPUT Elf2Mem PRE_BUILD COMMAND ${PROGRAM_TOOL} -a ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME} -LHex)

add_custom_target(${CMAKE_PROJECT_NAME}.mem DEPENDS Elf2Mem)

add_custom_command(OUTPUT Elf2Mif PRE_BUILD COMMAND ${PROGRAM_TOOL} -a ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME} -AMif)

add_custom_target(${CMAKE_PROJECT_NAME}.mif DEPENDS Elf2Mif)

# Specify the command to execute to copy the .elf to .bin
add_custom_command(OUTPUT Elf2Bin PRE_BUILD COMMAND ${CMAKE_OBJCOPY_COMPILER} ${CMAKE_OBJCOPY_FLAGS} -O binary ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME}.bin)
# Specify the rule to the makefile that will execute the custom command
add_custom_target(${CMAKE_PROJECT_NAME}.bin DEPENDS Elf2Bin)

# Specify the command to execute to copy the .elf to .srec
add_custom_command(OUTPUT Elf2Srec PRE_BUILD COMMAND ${CMAKE_OBJCOPY_COMPILER} ${CMAKE_OBJCOPY_FLAGS} -O srec ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME}.srec)
# Specify the rule to the makefile that will execute the custom command
add_custom_target(${CMAKE_PROJECT_NAME}.srec DEPENDS Elf2Srec)

# Specify the command to execute to copy the .elf to .hex
add_custom_command(OUTPUT Elf2Hex PRE_BUILD COMMAND ${CMAKE_OBJCOPY_COMPILER} ${CMAKE_OBJCOPY_FLAGS} -O ihex ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME}.hex)
# Specify the rule to the makefile that will execute the custom command
add_custom_target(${CMAKE_PROJECT_NAME}.hex DEPENDS Elf2Hex)

# Specify the command to execute to program the FPGA
add_custom_target(PROGRAM_FPGA_ROM COMMAND ${PROGRAM_TOOL} -p ${SERIAL_PORT} -a ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME} ${VERBOSE})

add_custom_target(PROGRAM_FPGA_RAM COMMAND ${PROGRAM_TOOL} -p ${SERIAL_PORT} -a ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME} -r ${VERBOSE})

add_custom_target(SHOW_SIZE COMMAND ${CMAKE_SIZE} --format=berkeley ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_PROJECT_NAME})