cmake_minimum_required(VERSION 3.5.0)
project(PSFExtractor VERSION 0.1.0 LANGUAGES C CXX)

add_executable(PSFExtractor src/PSFExtractor.cpp)

add_subdirectory(libs/pugixml)
target_link_libraries(PSFExtractor Cabinet pugixml)