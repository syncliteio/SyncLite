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
if(WIN32)
    file(GLOB _synclite_versioned_libs_underscore
        RELATIVE "${SYNCLITE_LIB_DIR}"
        "${SYNCLITE_LIB_DIR}/synclite_*_*.lib")
    if(_synclite_versioned_libs_underscore)
        set(_synclite_versioned_libs ${_synclite_versioned_libs_underscore})
    else()
        file(GLOB _synclite_versioned_libs
            RELATIVE "${SYNCLITE_LIB_DIR}"
            "${SYNCLITE_LIB_DIR}/synclite_*.lib")
    endif()
elseif(APPLE)
    file(GLOB _synclite_versioned_libs_underscore
        RELATIVE "${SYNCLITE_LIB_DIR}"
        "${SYNCLITE_LIB_DIR}/libsynclite_*_*.dylib")
    if(_synclite_versioned_libs_underscore)
        set(_synclite_versioned_libs ${_synclite_versioned_libs_underscore})
    else()
        file(GLOB _synclite_versioned_libs
            RELATIVE "${SYNCLITE_LIB_DIR}"
            "${SYNCLITE_LIB_DIR}/libsynclite_*.dylib")
    endif()
else()
    file(GLOB _synclite_versioned_libs_underscore
        RELATIVE "${SYNCLITE_LIB_DIR}"
        "${SYNCLITE_LIB_DIR}/libsynclite_*_*.so")
    if(_synclite_versioned_libs_underscore)
        set(_synclite_versioned_libs ${_synclite_versioned_libs_underscore})
    else()
        file(GLOB _synclite_versioned_libs
            RELATIVE "${SYNCLITE_LIB_DIR}"
            "${SYNCLITE_LIB_DIR}/libsynclite_*.so")
    endif()
endif()
set(_synclite_lib_names)
foreach(_lib IN LISTS _synclite_versioned_libs)
    get_filename_component(_basename "${_lib}" NAME_WE)
    list(APPEND _synclite_lib_names "${_basename}")
    string(REGEX REPLACE "^lib" "" _basename "${_basename}")
    list(APPEND _synclite_lib_names "${_basename}")
endforeach()
list(APPEND _synclite_lib_names logger_bindings_c)
list(REMOVE_DUPLICATES _synclite_lib_names)

set(_synclite_lib_candidates)
foreach(_lib IN LISTS _synclite_versioned_libs)
    list(APPEND _synclite_lib_candidates "${SYNCLITE_LIB_DIR}/${_lib}")
endforeach()
if(WIN32)
    list(APPEND _synclite_lib_candidates
        "${SYNCLITE_LIB_DIR}/logger_bindings_c.lib")
elseif(APPLE)
    list(APPEND _synclite_lib_candidates
        "${SYNCLITE_LIB_DIR}/libsynclite.dylib")
else()
    list(APPEND _synclite_lib_candidates
        "${SYNCLITE_LIB_DIR}/libsynclite.so")
endif()

foreach(_candidate IN LISTS _synclite_lib_candidates)
    if(EXISTS "${_candidate}")
        set(SYNCLITE_LIB "${_candidate}")
        break()
    endif()
endforeach()

if(NOT SYNCLITE_LIB)
    message(FATAL_ERROR
        "Could not find a synclite_c / libsynclite_<revision> library in ${SYNCLITE_LIB_DIR}.\n"
        "Either build the cdylib (cargo build -p synclite-c [--release])\n"
        "or pass -DSYNCLITE_SDK_DIR=<prebuilt-sdk>.")
endif()

message(STATUS "synclite include dir: ${SYNCLITE_INCLUDE_DIR}")
message(STATUS "synclite library    : ${SYNCLITE_LIB}")

# On Windows the runtime dll lives next to the import lib. Locate by basename
# so we copy the actual file the linker resolved (typically
# libsynclite_<revision>.dll) next to the built .exe.
if(WIN32)
    file(GLOB _synclite_runtime_dll_candidates
        LIST_DIRECTORIES false
        "${SYNCLITE_LIB_DIR}/synclite_*_*.dll")
    if(NOT _synclite_runtime_dll_candidates)
        file(GLOB _synclite_runtime_dll_candidates
            LIST_DIRECTORIES false
            "${SYNCLITE_LIB_DIR}/synclite_*.dll")
    endif()
    if(_synclite_runtime_dll_candidates)
        list(GET _synclite_runtime_dll_candidates 0 SYNCLITE_RUNTIME_DLL)
    else()
        get_filename_component(_synclite_lib_filename "${SYNCLITE_LIB}" NAME_WE)
        set(SYNCLITE_RUNTIME_DLL "${SYNCLITE_LIB_DIR}/${_synclite_lib_filename}.dll")
        if(NOT EXISTS "${SYNCLITE_RUNTIME_DLL}")
            # Some release archives ship the dll with a `lib` prefix that the .lib
            # doesn't carry; try the inverse.
            set(SYNCLITE_RUNTIME_DLL "${SYNCLITE_LIB_DIR}/lib${_synclite_lib_filename}.dll")
        endif()
    endif()

    # DuckDB-backed devices need duckdb.dll available at run time too.
    # Search the release-native folder first, then fall back to the Rust build
    # output when the sample is built from a source checkout.
    find_file(SYNCLITE_DUCKDB_DLL
        NAMES duckdb.dll
        HINTS "${SYNCLITE_LIB_DIR}"
              "${SYNCLITE_LIB_DIR}/deps"
              "${SYNCLITE_LIB_DIR}/../deps"
              "${CMAKE_CURRENT_SOURCE_DIR}/build-run/Release"
              "${CMAKE_CURRENT_SOURCE_DIR}/build/Release"
              "${CMAKE_CURRENT_BINARY_DIR}/Release"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/${SYNCLITE_PROFILE}"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/debug"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/release"
        NO_DEFAULT_PATH)
    if(SYNCLITE_DUCKDB_DLL)
        message(STATUS "duckdb runtime dll  : ${SYNCLITE_DUCKDB_DLL}")
    else()
        message(WARNING
            "duckdb.dll not found near ${SYNCLITE_LIB_DIR} or Rust target outputs.\n"
            "${SYNCLITE_RUNTIME_DLL} imports duckdb.dll, so the duckdb-backed sample\n"
            "will fail to load unless duckdb.dll is on the loader path at run time.")
    endif()
else()
    # On Unix the cdylib we linked against IS the runtime shared object, so we
    # stage that exact file (e.g. libsynclite_1_0_0.so / .dylib) next to the
    # sample so developers do not have to fiddle with LD_LIBRARY_PATH.
    set(SYNCLITE_RUNTIME_LIB "${SYNCLITE_LIB}")

    if(APPLE)
        set(_synclite_duckdb_names libduckdb.dylib libduckdb.so)
    else()
        set(_synclite_duckdb_names libduckdb.so)
    endif()
    find_file(SYNCLITE_DUCKDB_LIB
        NAMES ${_synclite_duckdb_names}
        HINTS "${SYNCLITE_LIB_DIR}"
              "${SYNCLITE_LIB_DIR}/deps"
              "${SYNCLITE_LIB_DIR}/../deps"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/${SYNCLITE_PROFILE}"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/debug"
              "${CMAKE_CURRENT_SOURCE_DIR}/../../synclite-logger-rust/target/release"
        NO_DEFAULT_PATH)
    if(SYNCLITE_DUCKDB_LIB)
        message(STATUS "duckdb runtime lib  : ${SYNCLITE_DUCKDB_LIB}")
    else()
        message(WARNING
            "Could not locate a duckdb shared library near ${SYNCLITE_LIB_DIR}.\n"
            "The duckdb-backed sample will fail to load unless duckdb is on the loader path.")
    endif()
endif()

function(add_synclite_sample name)
    add_executable(${name} ${name}.cpp)
    target_include_directories(${name} PRIVATE "${SYNCLITE_INCLUDE_DIR}")
    target_link_libraries(${name} PRIVATE "${SYNCLITE_LIB}")
    if(WIN32)
        set(_runtime_copy_commands)
        if(EXISTS "${SYNCLITE_RUNTIME_DLL}")
            list(APPEND _runtime_copy_commands
                COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:${name}>"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${SYNCLITE_RUNTIME_DLL}"
                        "$<TARGET_FILE_DIR:${name}>/")
        endif()
        if(EXISTS "${SYNCLITE_DUCKDB_DLL}")
            list(APPEND _runtime_copy_commands
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${SYNCLITE_DUCKDB_DLL}"
                        "$<TARGET_FILE_DIR:${name}>/duckdb.dll")
        endif()
        if(_runtime_copy_commands)
            add_custom_command(TARGET ${name} POST_BUILD
                ${_runtime_copy_commands}
                VERBATIM)
        endif()
    else()
        # Resolve the sample's shared-library dependencies relative to its own
        # location so the copied runtime libs are found without LD_LIBRARY_PATH.
        if(APPLE)
            set_target_properties(${name} PROPERTIES
                BUILD_RPATH "@loader_path"
                INSTALL_RPATH "@loader_path")
        else()
            set_target_properties(${name} PROPERTIES
                BUILD_RPATH "$ORIGIN"
                INSTALL_RPATH "$ORIGIN")
        endif()
        set(_runtime_copy_commands)
        if(SYNCLITE_RUNTIME_LIB AND EXISTS "${SYNCLITE_RUNTIME_LIB}")
            list(APPEND _runtime_copy_commands
                COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:${name}>"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${SYNCLITE_RUNTIME_LIB}"
                        "$<TARGET_FILE_DIR:${name}>/")
        endif()
        if(SYNCLITE_DUCKDB_LIB)
            get_filename_component(_synclite_duckdb_name "${SYNCLITE_DUCKDB_LIB}" NAME)
            list(APPEND _runtime_copy_commands
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${SYNCLITE_DUCKDB_LIB}"
                        "$<TARGET_FILE_DIR:${name}>/${_synclite_duckdb_name}")
        endif()
        if(_runtime_copy_commands)
            add_custom_command(TARGET ${name} POST_BUILD
                ${_runtime_copy_commands}
                VERBATIM)
        endif()
    endif()
endfunction()

add_synclite_sample(synclite_rusqlite_postgres)
