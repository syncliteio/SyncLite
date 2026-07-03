cmake_minimum_required(VERSION 3.16)
project(synclite_cpp_samples LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ----------------------------------------------------------------------
# Locate the synclite C ABI headers + cdylib. Three layouts:
#
#   1. Platform release (auto-detected) — when this sample sits inside an
#      extracted release tree at <release>/sample-apps/cpp/,
#      headers are at <release>/lib/native/include/ and libs at
#      <release>/lib/native/. No CMake flags needed:
#          cmake -S . -B build
#          cmake --build build --config Release
#
#   2. In-tree source build — point at the Rust workspace produced by
#      `cargo build [--release] -p synclite-c`:
#          cmake -S . -B build \
#                -DSYNCLITE_RUST_ROOT=../../synclite-logger-rust \
#                -DSYNCLITE_PROFILE=release
#
#   3. Prebuilt SDK — drop in a SyncLite C/C++ SDK with this layout:
#          <SYNCLITE_SDK_DIR>/include/synclite.{h,hpp}
#          <SYNCLITE_SDK_DIR>/lib/{synclite_c,synclite_oss}.{dll,lib,so,dylib}
#          cmake -S . -B build -DSYNCLITE_SDK_DIR=C:/path/to/synclite-c-sdk
# ----------------------------------------------------------------------

set(SYNCLITE_SDK_DIR ""
    CACHE PATH "Path to a prebuilt SyncLite C/C++ SDK (overrides RUST_ROOT)")
set(SYNCLITE_RUST_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust"
    CACHE PATH "Path to synclite-logger-rust Cargo workspace root")
set(SYNCLITE_PROFILE "debug"
    CACHE STRING "Cargo build profile (debug|release)")

# Auto-detect platform-release layout: <release>/sample-apps/cpp
# sits 3 levels under <release>, whose lib/native/ ships the prebuilt cdylib +
# import lib and (since this assembly change) lib/native/include/ ships the C
# ABI headers.
set(_synclite_release_root "${CMAKE_CURRENT_SOURCE_DIR}/../..")
if(NOT SYNCLITE_SDK_DIR
   AND EXISTS "${_synclite_release_root}/lib/native/include/synclite.h")
    set(SYNCLITE_INCLUDE_DIR "${_synclite_release_root}/lib/native/include")
    set(SYNCLITE_LIB_DIR     "${_synclite_release_root}/lib/native")
    message(STATUS "synclite: detected platform-release layout at ${_synclite_release_root}")
elseif(SYNCLITE_SDK_DIR)
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

# `synclite_c` is the in-tree source-build name; platform packages may ship
# versioned `libsynclite_<revision>*` names.
# find_library tries each discovered basename and handles the platform `lib`
# prefix automatically.
file(GLOB _synclite_versioned_libs
    RELATIVE "${SYNCLITE_LIB_DIR}"
    "${SYNCLITE_LIB_DIR}/libsynclite_*.lib"
    "${SYNCLITE_LIB_DIR}/libsynclite_*.so"
    "${SYNCLITE_LIB_DIR}/libsynclite_*.dylib")
set(_synclite_lib_names synclite_c logger_bindings_c)
foreach(_lib IN LISTS _synclite_versioned_libs)
    get_filename_component(_basename "${_lib}" NAME_WE)
    string(REGEX REPLACE "^lib" "" _basename "${_basename}")
    list(APPEND _synclite_lib_names "${_basename}")
endforeach()
list(REMOVE_DUPLICATES _synclite_lib_names)

find_library(SYNCLITE_LIB
    NAMES ${_synclite_lib_names}
    HINTS "${SYNCLITE_LIB_DIR}"
    NO_DEFAULT_PATH)

if(NOT SYNCLITE_LIB AND _synclite_versioned_libs)
    # Versioned names like libsynclite_1.0.0.lib are valid shipped artifacts,
    # but find_library can miss them when dots are present in the basename.
    if(WIN32)
        set(_synclite_preferred_ext ".lib")
    elseif(APPLE)
        set(_synclite_preferred_ext ".dylib")
    else()
        set(_synclite_preferred_ext ".so")
    endif()

    foreach(_lib IN LISTS _synclite_versioned_libs)
        if(_lib MATCHES "${_synclite_preferred_ext}$")
            set(SYNCLITE_LIB "${SYNCLITE_LIB_DIR}/${_lib}")
            break()
        endif()
    endforeach()

    if(NOT SYNCLITE_LIB)
        list(GET _synclite_versioned_libs 0 _synclite_first_lib)
        set(SYNCLITE_LIB "${SYNCLITE_LIB_DIR}/${_synclite_first_lib}")
    endif()
endif()

if(NOT SYNCLITE_LIB)
    message(FATAL_ERROR
        "Could not find a synclite_c / libsynclite_<revision> library in ${SYNCLITE_LIB_DIR}.\n"
        "Either build the cdylib (cargo build -p synclite-c [--release])\n"
        "or pass -DSYNCLITE_SDK_DIR=<prebuilt-sdk>.")
endif()

message(STATUS "synclite include dir: ${SYNCLITE_INCLUDE_DIR}")
message(STATUS "synclite library    : ${SYNCLITE_LIB}")

# On Windows the runtime dll lives next to the import lib. Locate by basename
# so we copy the actual file the linker resolved (synclite_c.dll OR
# libsynclite_<revision>.dll).
if(WIN32)
    get_filename_component(_synclite_lib_filename "${SYNCLITE_LIB}" NAME_WE)
    set(SYNCLITE_RUNTIME_DLL "${SYNCLITE_LIB_DIR}/${_synclite_lib_filename}.dll")
    set(SYNCLITE_RUNTIME_DLL_ALIAS "")
    if(NOT EXISTS "${SYNCLITE_RUNTIME_DLL}")
        # Some release archives ship the dll with a `lib` prefix that the .lib
        # doesn't carry; try the inverse.
        set(SYNCLITE_RUNTIME_DLL "${SYNCLITE_LIB_DIR}/lib${_synclite_lib_filename}.dll")
    endif()
    # Versioned platform packages may link via libsynclite_<revision>.lib while
    # the executable import table still expects synclite_c.dll.
    if(_synclite_lib_filename MATCHES "^libsynclite_")
        set(SYNCLITE_RUNTIME_DLL_ALIAS "synclite_c.dll")
    endif()

    # DuckDB-backed devices need duckdb.dll available at run time too.
    # Search the release-native folder first, then fall back to the Rust build
    # output when the sample is built from a source checkout.
    find_file(SYNCLITE_DUCKDB_DLL
        NAMES duckdb.dll
        HINTS "${SYNCLITE_LIB_DIR}"
              "${SYNCLITE_LIB_DIR}/deps"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/${SYNCLITE_PROFILE}"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/debug"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/release"
        NO_DEFAULT_PATH)
    if(SYNCLITE_DUCKDB_DLL)
        message(STATUS "duckdb runtime dll  : ${SYNCLITE_DUCKDB_DLL}")
    else()
        message(WARNING
            "duckdb.dll not found near ${SYNCLITE_LIB_DIR}.\n"
            "If you want to try DuckDB or DuckDB_STORE devices, copy duckdb.dll "
            "next to the built .exe manually or build the Rust side with the "
            "download-lib flow so it is produced.")
    endif()
endif()

function(add_synclite_sample name)
    add_executable(${name} ${name}.cpp)
    target_include_directories(${name} PRIVATE "${SYNCLITE_INCLUDE_DIR}")
    target_link_libraries(${name} PRIVATE "${SYNCLITE_LIB}")
    if(WIN32)
        if(EXISTS "${SYNCLITE_RUNTIME_DLL}")
            # Copy the cdylib next to the .exe so it loads at run time.
            add_custom_command(TARGET ${name} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${SYNCLITE_RUNTIME_DLL}"
                        "$<TARGET_FILE_DIR:${name}>/")
            if(SYNCLITE_RUNTIME_DLL_ALIAS)
                add_custom_command(TARGET ${name} POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different
                            "${SYNCLITE_RUNTIME_DLL}"
                            "$<TARGET_FILE_DIR:${name}>/${SYNCLITE_RUNTIME_DLL_ALIAS}")
            endif()
        endif()
        if(SYNCLITE_DUCKDB_DLL)
            add_custom_command(TARGET ${name} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${SYNCLITE_DUCKDB_DLL}"
                        "$<TARGET_FILE_DIR:${name}>/duckdb.dll")
        endif()
    endif()
endfunction()

add_synclite_sample(synclite_rusqlite_postgres)
