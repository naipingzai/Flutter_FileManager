cmake_minimum_required(VERSION 3.16)

project(text_ops LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(text_ops SHARED
    text_ops.cpp
)

target_include_directories(text_ops
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
)