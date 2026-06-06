cmake_minimum_required(VERSION 3.16)
project(synclite_cpp_samples LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ----------------------------------------------------------------------
# Locate the synclite C ABI headers + cdylib. Two paths:
#
#   Option A (default) — build from source. Point at the Rust workspace
#   produced by `cargo build [--release] -p synclite-c`:
#       cmake -S . -B build \
#             -DSYNCLITE_RUST_ROOT=../../../synclite-logger-rust \
#             -DSYNCLITE_PROFILE=release
#
#   Option B — consume a prebuilt SDK with this layout:
#       <SYNCLITE_SDK_DIR>/include/synclite.{h,hpp}
#       <SYNCLITE_SDK_DIR>/lib/{synclite_c.dll,.lib,.so,.dylib}
#       cmake -S . -B build -DSYNCLITE_SDK_DIR=C:/path/to/synclite-c-sdk
# ----------------------------------------------------------------------

set(SYNCLITE_SDK_DIR ""
    CACHE PATH "Path to a prebuilt SyncLite C/C++ SDK (overrides RUST_ROOT)")
set(SYNCLITE_RUST_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../synclite-logger-rust"
    CACHE PATH "Path to synclite-logger-rust Cargo workspace root")
set(SYNCLITE_PROFILE "debug"
    CACHE STRING "Cargo build profile (debug|release)")

if(SYNCLITE_SDK_DIR)
    set(SYNCLITE_INCLUDE_DIR "${SYNCLITE_SDK_DIR}/include")
    set(SYNCLITE_LIB_DIR     "${SYNCLITE_SDK_DIR}/lib")
else()
    set(SYNCLITE_INCLUDE_DIR "${SYNCLITE_RUST_ROOT}/include")
    set(SYNCLITE_LIB_DIR     "${SYNCLITE_RUST_ROOT}/target/${SYNCLITE_PROFILE}")
endif()

if(NOT EXISTS "${SYNCLITE_INCLUDE_DIR}/synclite.h")
    message(FATAL_ERROR
        "synclite.h not found at ${SYNCLITE_INCLUDE_DIR}.\n"
        "Pass -DSYNCLITE_SDK_DIR=<prebuilt-sdk> or "
        "-DSYNCLITE_RUST_ROOT=<path-to-synclite-logger-rust>.")
endif()

find_library(SYNCLITE_LIB
    NAMES synclite_c logger_bindings_c
    HINTS "${SYNCLITE_LIB_DIR}"
    NO_DEFAULT_PATH)

if(NOT SYNCLITE_LIB)
    message(FATAL_ERROR
        "Could not find synclite_c in ${SYNCLITE_LIB_DIR}.\n"
        "Either build the cdylib (cargo build -p synclite-c [--release])\n"
        "or pass -DSYNCLITE_SDK_DIR=<prebuilt-sdk>.")
endif()

message(STATUS "synclite include dir: ${SYNCLITE_INCLUDE_DIR}")
message(STATUS "synclite library    : ${SYNCLITE_LIB}")

function(add_synclite_sample name)
    add_executable(${name} ${name}.cpp)
    target_include_directories(${name} PRIVATE "${SYNCLITE_INCLUDE_DIR}")
    target_link_libraries(${name} PRIVATE "${SYNCLITE_LIB}")
    if(WIN32)
        # Copy the cdylib next to the .exe so it loads at run time.
        add_custom_command(TARGET ${name} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${SYNCLITE_LIB_DIR}/synclite_c.dll"
                    "$<TARGET_FILE_DIR:${name}>/synclite_c.dll")
    endif()
endfunction()

add_synclite_sample(synclite_rusqlite)
add_synclite_sample(synclite_rusqlite_store)
add_synclite_sample(synclite_streaming)
add_synclite_sample(synclite_duckdb)
add_synclite_sample(synclite_duckdb_store)
