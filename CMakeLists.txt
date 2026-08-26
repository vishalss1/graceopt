cmake_minimum_required(VERSION 3.20)
project(GraceOpt LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Locate an installed LLVM. Pass -DLLVM_DIR=<prefix>/lib/cmake/llvm if it is
# not on the default search path.
find_package(LLVM REQUIRED CONFIG)
message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION} at ${LLVM_DIR}")
message(STATUS "LLVM host triple: ${LLVM_HOST_TRIPLE}")

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)

separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})
include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
include_directories(${PROJECT_SOURCE_DIR}/include)

# LLVM is usually built without RTTI and exceptions; match it so the plugin
# shares an ABI with the host opt/clang binaries.
if(NOT LLVM_ENABLE_RTTI)
  add_compile_options(-fno-rtti)
endif()
if(NOT LLVM_ENABLE_EH)
  add_compile_options(-fno-exceptions)
endif()

add_subdirectory(lib)

# `cmake --build build --target check` runs the FileCheck-based regression
# tests with the freshly built plugin.
find_package(Python3 COMPONENTS Interpreter)
if(Python3_Interpreter_FOUND)
  add_custom_target(check
    COMMAND ${Python3_EXECUTABLE} ${PROJECT_SOURCE_DIR}/test/run_tests.py
            --llvm-bin ${LLVM_TOOLS_BINARY_DIR}
            --plugin $<TARGET_FILE:GraceOpt>
    DEPENDS GraceOpt
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    COMMENT "Running GraceOpt regression tests"
    USES_TERMINAL)
endif()
