cmake_minimum_required(VERSION 3.13)
project(file_ops LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(OpenSSL REQUIRED)
find_package(ZLIB REQUIRED)

add_library(file_ops SHARED
    file_ops.cpp
    file_ops_json.cpp
)

target_include_directories(file_ops PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(file_ops PRIVATE OpenSSL::Crypto ZLIB::ZLIB stdc++fs)
