cmake_minimum_required(VERSION 3.5.0)
project(PSFExtractor VERSION 3.0.9 LANGUAGES C CXX)

add_executable(PSFExtractor src/PSFExtractor.cpp)

add_subdirectory(libs/pugixml)
target_link_libraries(PSFExtractor Cabinet pugixml)

set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)