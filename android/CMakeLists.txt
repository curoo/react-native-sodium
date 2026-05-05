cmake_minimum_required(VERSION 3.4.1)

if(DEFINED ANDROID_ABI AND NOT "${ANDROID_ABI}" STREQUAL "")
  set(ANDROID_ARCH "${ANDROID_ABI}")
else()
  set(ANDROID_ARCH "${ANDROID_ARCH_NAME}")
endif()

if(ANDROID_ARCH STREQUAL "armeabi")
  set(ARCH_DIR "armv6")
elseif(ANDROID_ARCH STREQUAL "arm")
  set(ARCH_DIR "armv6")
elseif(ANDROID_ARCH STREQUAL "armeabi-v7a")
  set(ARCH_DIR "armv7-a")
elseif(ANDROID_ARCH STREQUAL "arm64-v8a" OR ANDROID_ARCH STREQUAL "arm64")
  set(ARCH_DIR "armv8-a+crypto")
elseif(ANDROID_ARCH STREQUAL "x86")
  set(ARCH_DIR "i686")
elseif(ANDROID_ARCH STREQUAL "x86_64")
  set(ARCH_DIR "westmere")
elseif(ANDROID_ARCH STREQUAL "mips")
  set(ARCH_DIR "mips32")
elseif(ANDROID_ARCH STREQUAL "mips64")
  set(ARCH_DIR "mips64r6")
else()
  message(FATAL_ERROR "Unsupported Android architecture: ${ANDROID_ARCH}")
endif()

set(LIBSODIUM_ARCH_DIR "")
if(EXISTS "${PROJECT_SOURCE_DIR}/../libsodium/build/libsodium-android-${ARCH_DIR}")
  set(LIBSODIUM_ARCH_DIR "${PROJECT_SOURCE_DIR}/../libsodium/build/libsodium-android-${ARCH_DIR}")
elseif(EXISTS "${PROJECT_SOURCE_DIR}/../libsodium/libsodium-android-${ARCH_DIR}")
  set(LIBSODIUM_ARCH_DIR "${PROJECT_SOURCE_DIR}/../libsodium/libsodium-android-${ARCH_DIR}")
else()
  message(FATAL_ERROR "Unable to locate libsodium for ${ARCH_DIR}. Run postinstall or rebuild to generate precompiled artifacts.")
endif()

set(SODIUM_INCLUDE_DIR "${LIBSODIUM_ARCH_DIR}/include")
set(SODIUM_STATIC_LIB "${LIBSODIUM_ARCH_DIR}/lib/libsodium.a")
set(SODIUM_SHARED_LIB "${LIBSODIUM_ARCH_DIR}/lib/libsodium.so")

include_directories(${SODIUM_INCLUDE_DIR})
set(ABI_DIR "${ANDROID_ABI}")
if("${ABI_DIR}" STREQUAL "")
  set(ABI_DIR "${ANDROID_ARCH}")
endif()

if(EXISTS "${SODIUM_STATIC_LIB}")
  add_library(sodium STATIC IMPORTED)
  set_target_properties(sodium PROPERTIES IMPORTED_LOCATION "${SODIUM_STATIC_LIB}")

  # Keep the APK/AAB surface small: sodium-jni.so contains libsodium, so do not
  # package a second libsodium.so when a usable static archive is available.
  file(REMOVE "${PROJECT_SOURCE_DIR}/lib/${ABI_DIR}/libsodium.so")
elseif(EXISTS "${SODIUM_SHARED_LIB}")
  add_library(sodium SHARED IMPORTED)
  set_target_properties(sodium PROPERTIES IMPORTED_LOCATION "${SODIUM_SHARED_LIB}")
  file(COPY "${SODIUM_SHARED_LIB}" DESTINATION "${PROJECT_SOURCE_DIR}/lib/${ABI_DIR}")
elseif(EXISTS "${SODIUM_STATIC_LIB}")
  add_library(sodium STATIC IMPORTED)
  set_target_properties(sodium PROPERTIES IMPORTED_LOCATION "${SODIUM_STATIC_LIB}")
else()
  message(FATAL_ERROR "No libsodium static or shared library found in ${LIBSODIUM_ARCH_DIR}/lib")
endif()

add_library(sodium-jni SHARED src/main/cpp/sodium-jni.c)
target_link_libraries(sodium-jni sodium)

# Force 16 KB-compatible segment alignment for every Android ABI we ship.
# Google Play validates all native libraries in the AAB, including emulator ABIs
# such as x86_64 if they are present.
set_property(
  TARGET sodium-jni
  APPEND_STRING
  PROPERTY LINK_FLAGS
  " -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
)
