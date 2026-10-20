cmake_minimum_required(VERSION 3.16)

project(autopilot_config VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network VirtualKeyboard Concurrent)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appautopilot_config
    main.cpp
    TcpServerService.h
    TcpServerService.cpp
    Stm32ProtocolParser.h
    Stm32ProtocolParser.cpp
    ProtocolPacketBuilder.h
    ProtocolPacketBuilder.cpp
    ProtocolPacketBuilderWrapper.h
    ProtocolPacketBuilderWrapper.cpp
    DataDisplayProcessor.h
    DataDisplayProcessor.cpp
    IpAddressService.h
    IpAddressService.cpp
    SystemService.h
    SystemService.cpp
    DataTimeoutManager.h
    DataTimeoutManager.cpp
    ParamFileManager.h
    ParamFileManager.cpp
    RemoteControllerService.h
    RemoteControllerService.cpp
    BatteryService.h
    BatteryService.cpp
)

qt_add_qml_module(appautopilot_config
    URI autopilot_config
    QML_FILES
        Main.qml
        LogControl.qml
        ParameterControl.qml
        ImuControl.qml
        NumericKeyboard.qml
        RemoteControl.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appautopilot_config PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appautopilot_config
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appautopilot_config
    PRIVATE Qt6::Quick Qt6::Network Qt6::VirtualKeyboard Qt6::Concurrent
)

include(GNUInstallDirs)
install(TARGETS appautopilot_config
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
