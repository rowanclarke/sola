# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(rust_library LANGUAGES C)

if (WIN32)
  set(RUST_LIB_NAME "rust.dll")
elseif(APPLE)
  set(RUST_LIB_NAME "librust.dylib")
else()
  set(RUST_LIB_NAME "librust.so")
endif()

set(RUST_OUTPUT "${PROJECT_BINARY_DIR}/release/${RUST_LIB_NAME}")
file(GLOB_RECURSE RUST_SOURCES "${PROJECT_SOURCE_DIR}/*.rs")

add_custom_command(
  OUTPUT ${RUST_OUTPUT}
  COMMAND cargo build --release --target-dir ${PROJECT_BINARY_DIR}
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  DEPENDS ${RUST_SOURCES}
  COMMENT "Building Rust library"
  VERBATIM
)

add_custom_target(rust_build ALL
  DEPENDS ${RUST_OUTPUT}
)

add_library(rust SHARED IMPORTED GLOBAL)

set_target_properties(rust PROPERTIES
  IMPORTED_LOCATION ${RUST_OUTPUT}
  OUTPUT_NAME "rust"
)

target_compile_definitions(rust INTERFACE DART_SHARED_LIB)

