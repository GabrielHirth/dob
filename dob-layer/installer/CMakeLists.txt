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
    pages/welcome_page.cpp
    pages/disk_page.cpp
    pages/user_page.cpp
    pages/summary_page.cpp
    engine/plan_install.cpp
    engine/install_engine.cpp
)

target_link_libraries(dob-installer Qt6::Widgets)

# Unit test target for planInstall (needs QtCore for QString in config.h)
add_executable(plan_install_test
    engine/plan_install_test.cpp
    engine/plan_install.cpp
    config.cpp
)

target_link_libraries(plan_install_test Qt6::Core)
target_compile_definitions(plan_install_test PRIVATE DOB_UNIT_TEST)

install(TARGETS dob-installer RUNTIME DESTINATION /usr/local/bin)
