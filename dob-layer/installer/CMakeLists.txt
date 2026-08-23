cmake_minimum_required(VERSION 3.16)

project(dob-installer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)

qt_add_resources(dob-installer dob-resources ALIAS dob-resources-alias PREFIX / FILES resources.qrc)

add_executable(dob-installer
    main.cpp
    config.cpp
    installer.cpp
)

target_link_libraries(dob-installer Qt6::Widgets)

install(TARGETS dob-installer RUNTIME DESTINATION /usr/local/bin)
