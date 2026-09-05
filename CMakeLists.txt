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
if(NOT LLVM_VERSION_MAJOR EQUAL 22)
  message(FATAL_ERROR "GraceOpt currently supports LLVM 22; use a matching LLVM 22 toolchain")
endif()
if(WIN32 AND NOT LLVM_LINK_LLVM_DYLIB)
  message(FATAL_ERROR "Windows requires an LLVM distribution with the shared LLVM library")
endif()
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
  if(MSVC)
    add_compile_options(/GR-)
  else()
    add_compile_options(-fno-rtti)
  endif()
endif()
if(NOT LLVM_ENABLE_EH)
  if(MSVC)
    add_compile_options(/EHs-c-)
  else()
    add_compile_options(-fno-exceptions)
  endif()
endif()

add_subdirectory(lib)

# `cmake --build build --target check` runs the FileCheck-based regression
# tests with the freshly built plugin.
find_package(Python3 COMPONENTS Interpreter)
if(Python3_Interpreter_FOUND)
  enable_testing()
  add_test(NAME framework
    COMMAND ${Python3_EXECUTABLE} -m unittest discover -s ${PROJECT_SOURCE_DIR}/test -p test_*.py)
  add_test(NAME ir
    COMMAND ${Python3_EXECUTABLE} ${PROJECT_SOURCE_DIR}/test/run_tests.py
            --llvm-bin ${LLVM_TOOLS_BINARY_DIR} --plugin $<TARGET_FILE:GraceOpt>)
  add_test(NAME benchmark-smoke
    COMMAND ${Python3_EXECUTABLE} ${PROJECT_SOURCE_DIR}/scripts/benchmark.py
            --llvm-bin ${LLVM_TOOLS_BINARY_DIR} --plugin $<TARGET_FILE:GraceOpt>
            --kernels saxpy matmul --size 32 --variants stock grace
            --samples 2 --compile-repeats 1 --target-seconds 0.005
            --output ${PROJECT_BINARY_DIR}/benchmark-smoke.json
            --artifact-dir ${PROJECT_BINARY_DIR}/benchmark-smoke)
  add_test(NAME aarch64-codegen
    COMMAND ${Python3_EXECUTABLE} ${PROJECT_SOURCE_DIR}/scripts/inspect_codegen.py
            --llvm-bin ${LLVM_TOOLS_BINARY_DIR} --plugin $<TARGET_FILE:GraceOpt>
            --profiles grace-sve128 --levels O2
            --output ${PROJECT_BINARY_DIR}/codegen-smoke)
  set_tests_properties(framework ir benchmark-smoke aarch64-codegen PROPERTIES
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR} TIMEOUT 180)
  add_custom_target(check
    COMMAND ${Python3_EXECUTABLE} -m unittest discover -s ${PROJECT_SOURCE_DIR}/test -p test_*.py
    COMMAND ${Python3_EXECUTABLE} ${PROJECT_SOURCE_DIR}/test/run_tests.py
            --llvm-bin ${LLVM_TOOLS_BINARY_DIR}
            --plugin $<TARGET_FILE:GraceOpt>
    DEPENDS GraceOpt
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    COMMENT "Running GraceOpt regression tests"
    USES_TERMINAL)
  add_custom_target(bench
    COMMAND ${Python3_EXECUTABLE} ${PROJECT_SOURCE_DIR}/scripts/benchmark.py
            --llvm-bin ${LLVM_TOOLS_BINARY_DIR} --plugin $<TARGET_FILE:GraceOpt>
    DEPENDS GraceOpt WORKING_DIRECTORY ${PROJECT_SOURCE_DIR} USES_TERMINAL)
endif()
