project(NitroAudioRecorderPlayer)
cmake_minimum_required(VERSION 3.9.0)

set(PACKAGE_NAME NitroAudioRecorderPlayer)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_CXX_STANDARD 20)

# Define C++ library and add all sources
add_library(${PACKAGE_NAME} SHARED src/main/cpp/cpp-adapter.cpp)

# Add Nitrogen specs :)
include(${CMAKE_SOURCE_DIR}/../nitrogen/generated/android/NitroAudioRecorderPlayer+autolinking.cmake)

# Workaround for NitroModules prefab not including the library
# Find the actual library file
set(NITRO_LIB_PATH "${CMAKE_SOURCE_DIR}/../example/node_modules/react-native-nitro-modules/android/build/intermediates/cmake/debug/obj/${ANDROID_ABI}/libNitroModules.so")
if(EXISTS ${NITRO_LIB_PATH})
    target_link_libraries(${PACKAGE_NAME} ${NITRO_LIB_PATH})
else()
    # Try alternate path
    set(NITRO_LIB_PATH "${CMAKE_SOURCE_DIR}/../example/node_modules/react-native-nitro-modules/android/build/intermediates/cxx/Debug/6w6i364c/obj/${ANDROID_ABI}/libNitroModules.so")
    if(EXISTS ${NITRO_LIB_PATH})
        target_link_libraries(${PACKAGE_NAME} ${NITRO_LIB_PATH})
    endif()
endif()

# Set up local includes
include_directories("src/main/cpp" "../cpp")

find_library(LOG_LIB log)

# Link additional Android libraries
target_link_libraries(
        ${PACKAGE_NAME}
        ${LOG_LIB}
        android # <-- Android core
)
