# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Debug")
  file(REMOVE_RECURSE
  "CMakeFiles\\appautopilot_config_autogen.dir\\AutogenUsed.txt"
  "CMakeFiles\\appautopilot_config_autogen.dir\\ParseCache.txt"
  "appautopilot_config_autogen"
  )
endif()
