cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

# ============================================================
# 链接 C++ 静态库（base + platform 分离，直接集成进可执行文件）
# 使用 --whole-archive 强制包含所有符号，--export-dynamic 导出符号
# 供 Dart FFI 通过 DynamicLibrary.process() 查找
# ============================================================
target_link_libraries(${BINARY_NAME} PRIVATE
    -Wl,--whole-archive
    core
    media
    -Wl,--no-whole-archive
)

# 导出所有符号到动态符号表，FFI lookup 需要
target_link_options(${BINARY_NAME} PRIVATE -Wl,--export-dynamic)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
