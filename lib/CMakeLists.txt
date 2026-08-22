# The plugin is a MODULE library loaded by opt via -load-pass-plugin or by
# clang via -fpass-plugin. We link against the LLVM dylib so that symbols
# resolve against the same copy of LLVM the host tool uses.
add_library(GraceOpt MODULE
  Plugin.cpp
)

set_target_properties(GraceOpt PROPERTIES
  PREFIX ""
  OUTPUT_NAME "GraceOpt"
)

if(LLVM_LINK_LLVM_DYLIB)
  target_link_libraries(GraceOpt PRIVATE LLVM)
else()
  # Statically linked LLVM: rely on the host binary exporting its symbols.
  if(APPLE)
    target_link_options(GraceOpt PRIVATE -undefined dynamic_lookup)
  endif()
endif()
