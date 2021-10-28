#Collector depends on ExternalProject, is actually a convenience wrapper of it, with some utilities
#Also using FetchContent, obviously
include(ExternalProject)
include(FetchContent)


#Setting default build type, to fix issue with path calculated with no information provided in advance to cmake  NOT WORKING
if(CMAKE_BUILD_TYPE STREQUAL "")
    set(CMAKE_BUILD_TYPE Debug)
endif()



#getting global variables , like compiler, to pass it down to external projects
get_cmake_property(vars CACHE_VARIABLES)
message("\n") # this is for better understanding the output
foreach(var ${vars})
  get_property(currentHelpString CACHE "${var}" PROPERTY HELPSTRING)
    if("${currentHelpString}" MATCHES "No help, variable specified on the command line." OR "${currentHelpString}" STREQUAL "")
        message("${var} = [${${var}}]  --  ${currentHelpString}") # uncomment to see the variables being processed
        list(APPEND CL_ARGS "-D${var}=${${var}}")
    endif()
endforeach()
message("\n") # this is for better understanding the output




#Set variable to let the user choose if redownload all collections, even if they exist in cache, when doing a first time configuration. 
#If on, and do a really clean reconfigure of project(first time configuration), while offline, it will delete cache files and try to clone collection causing an error. 
#We recommend not turning it on unless needed, just using diferent tag vesions of collections ius enough for basic versioning, and cache 
#Actually it does not take into account if the downloaded folder is broken or not, i think.
set(FRESH_DOWNLOAD off CACHE BOOL "Tries to download a fresh copy of all dependencies")





#set the path to downloaded collections and installed collections
if(NOT DEFINED COLLECTOR_DIR )#checking if was provided by a parent project, ie: avoiding having duplicated collections
    if(DEFINED ENV{COLLECTOR_CACHE_ROOT})#checking if was provided by a environment variable, ie: caching all collections in one place, and avoid re cloning
        file(TO_CMAKE_PATH $ENV{COLLECTOR_CACHE_ROOT} COLLECTOR_CACHE_ROOT)#convert the path to CMake's internal format before handling it    
        set(COLLECTOR_DIR "${COLLECTOR_CACHE_ROOT}" CACHE INTERNAL "Copied from environment variable")
        message("\nThe path provided by the environment variable COLLECTOR_CACHE_ROOT, will be used for root path of downloaded collections: $ENV{COLLECTOR_CACHE_ROOT}\n")
    else()
        set(COLLECTOR_DIR "${PROJECT_SOURCE_DIR}/collected_deps" CACHE INTERNAL "Defined by current project")
    endif()
else()
    message(STATUS "COLLECTOR_DIR is DEFINED by something else(either parent project, or directly to cmake) to: ${COLLECTOR_DIR}")
endif()
if(NOT DEFINED COLLECTOR_INSTALLS )
    set (COLLECTOR_INSTALLS   ${PROJECT_SOURCE_DIR}/collections)
endif()





#Set variable for user choice of collections storage method
set(COLLECTOR_COLLECT_TOGETHER on CACHE BOOL "if on, store installed dependencies on common folder,ie the root of \"COLLECTOR_INSTALLS\" folder. if off install each dependency on particular folder,ie \"COLLECTOR_INSTALLS/dependency\"") 





#funcion to set up the ExternalProject_Add and needed folders of collector
function(collect_together)
    set(COLLECTOR_COLLECT_TOGETHER on CACHE BOOL "if on, store installed dependencies on common folder,ie the root of \"COLLECTOR_INSTALLS\" folder. if off install each dependency on particular folder,ie \"COLLECTOR_INSTALLS/dependency\"" FORCE) 
endfunction()

#funcion to set up the ExternalProject_Add and needed folders of collector
function(collect_apart)
    set(COLLECTOR_COLLECT_TOGETHER off CACHE BOOL "if on, store installed dependencies on common folder,ie the root of \"COLLECTOR_INSTALLS\" folder. if off install each dependency on particular folder,ie \"COLLECTOR_INSTALLS/dependency\"" FORCE) 
endfunction()




#Function to setup external projects
function(collect git_url version_tag dependent)
    
    #installs the collection to build folder of dependant, for development use mainly
    set(oneValueArgs RETURN_TARGET)
    cmake_parse_arguments(PARSE_ARGV 3 collection "${options}" "${oneValueArgs}" "${multiValueArgs}" )

    #here we are calculating a name for the downloaded dependency
    string(REGEX MATCH "[^/]+$" temp ${git_url})#getting the name based on the url
    set(collection_name _${temp})#adding _ to the collection name for compatibility with other cmake variables, like lib names when linking

    string(CONCAT temp ${git_url} ${version_tag})# computing has based on url, and tag
    string(SHA1 temp ${temp})
    string(CONCAT collection_name_hash_appended ${collection_name} "-" ${temp})#computing final name of downloaded collection

    #checking if the path to required headers/libs is given by command or sets it's own
    if(COLLECTOR_COLLECT_TOGETHER)
        set (COLLECTOR_CMAKE_INSTALL_PREFIX ${COLLECTOR_INSTALLS}/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}/${CMAKE_BUILD_TYPE}/ )
    else()
        set (COLLECTOR_CMAKE_INSTALL_PREFIX ${COLLECTOR_INSTALLS}/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}/${CMAKE_BUILD_TYPE}/${collection_name} )
    endif()

    #installs the collection to build folder of dependant, for development use mainly
    #need to set this as an extra path to install to, not override the custom path used for cache storage
    if(collection_RETURN_TARGET)
        set (COLLECTOR_CMAKE_INSTALL_PREFIX ${PROJECT_BINARY_DIR} )
        #install(TARGETS
        #    ${collection_name}
        #    DESTINATION ${PROJECT_BINARY_DIR} #el del parent_scope
        #)
    endif()

    #checking if the collection is already downloaded
    if(EXISTS "${COLLECTOR_DIR}/${collection_name_hash_appended}/CMakeLists.txt" AND NOT FRESH_DOWNLOAD)
        message("Using cache version of ${collection_name} in folder:  ${collection_name_hash_appended} ")
    else()
        # Define the variable to enable DOWNLOAD step
        set( COLLECTION_REPO GIT_REPOSITORY ${git_url})
        message("The collection ${collection_name} will be downloaded to folder:  ${collection_name_hash_appended} ")
    endif()

    #removing blank spaces(at least tested with one) to avoid issues with path containing blank spaces, and creating variable with name to append to folder containing compiled collection
    string(REGEX REPLACE "[ \t\r\n]" "" CMAKE_GENERATOR_NO_SPACES ${CMAKE_GENERATOR})

    if(NOT DEFINED ${collection_name}_DIR )
        ExternalProject_Add( ${collection_name}
            SOURCE_DIR          ${COLLECTOR_DIR}/${collection_name_hash_appended}
            ${COLLECTION_REPO}
            BINARY_DIR          "${COLLECTOR_DIR}/temp_workbench/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}-${CMAKE_GENERATOR_NO_SPACES}/${collection_name_hash_appended}/${CMAKE_BUILD_TYPE}/"
            GIT_TAG             ${version_tag}
            #CONFIGURE_COMMAND   ""
            #BUILD_COMMAND       ""
            #INSTALL_COMMAND     ""
            #INSTALL_DIR         ${COLLECTOR_CMAKE_INSTALL_PREFIX} #don't know what it is used for
            CMAKE_ARGS          ${CL_ARGS} -DCMAKE_INSTALL_PREFIX=${COLLECTOR_CMAKE_INSTALL_PREFIX} -DCOLLECTOR_DIR=${COLLECTOR_DIR} -DCOLLECTOR_INSTALLS=${COLLECTOR_INSTALLS}
        )
        add_dependencies(${dependent} ${collection_name})#wait for the download/configure/build/install of collection
        target_include_directories (${dependent} PRIVATE ${COLLECTOR_CMAKE_INSTALL_PREFIX}/include )#add path of include folder installed by current collection to dependent executable/library
        target_link_directories (${dependent} PRIVATE ${COLLECTOR_CMAKE_INSTALL_PREFIX}/lib)#add path off lib folder installed by current collection to dependent executable/library

        #setting the path to the installed collecction, the folder containing includes and libs
        SET (${collection_name}_DIR "${COLLECTOR_CMAKE_INSTALL_PREFIX}" )

        #propagate ${collection_name}_DIR to calling scope, ie the main cmakelist
        SET (${collection_name}_DIR ${${collection_name}_DIR} PARENT_SCOPE )

    else()
        message(STATUS "${collection_name}_DIR is DEFINED by something else")
    endif()

endfunction()






#Function to setup external projects, source only, is copied verbatin 
function(collect_src git_url version_tag dependent)
    
    #installs the collection to build folder of dependant, for development use mainly
    #set(oneValueArgs RETURN_TARGET)
    #cmake_parse_arguments(PARSE_ARGV 3 collection "${options}" "${oneValueArgs}" "${multiValueArgs}" )

    #here we are calculating a name for the downloaded dependency
    string(REGEX MATCH "[^/]+$" temp ${git_url})#getting the name based on the url
    set(collection_name _${temp})#adding _ to the collection name for compatibility with other cmake variables, like lib names when linking

    string(CONCAT temp ${git_url} ${version_tag})# computing has based on url, and tag
    string(SHA1 temp ${temp})
    string(CONCAT collection_name_hash_appended ${collection_name} "-" ${temp})#computing final name of downloaded collection

    #installs the collection to build folder of dependant, for development use mainly
    #need to set this as an extra path to install to, not override the custom path used for cache storage
    #if(collection_RETURN_TARGET)
    #    set (COLLECTOR_CMAKE_INSTALL_PREFIX ${PROJECT_BINARY_DIR} )
    #    #install(TARGETS
    #    #    ${collection_name}
    #    #    DESTINATION ${PROJECT_BINARY_DIR} #el del parent_scope
    #    #)
    #endif()




    #checking if the collection is already downloaded
    if(EXISTS "${COLLECTOR_DIR}/${collection_name_hash_appended}" AND NOT FRESH_DOWNLOAD)
        message("Using cache version of ${collection_name} in folder:  ${collection_name_hash_appended} ")
    else()
        message("The collection ${collection_name} is being downloaded to folder:  ${collection_name_hash_appended} ")
        FetchContent_Declare(
            ${collection_name}_cache
            SOURCE_DIR        ${COLLECTOR_DIR}/${collection_name_hash_appended}
            GIT_REPOSITORY              ${git_url}
            GIT_TAG                     ${version_tag}
        )
        FetchContent_Populate(
            ${collection_name}_cache
        )
    endif()

    #removing blank spaces(at least tested with one) to avoid issues with path containing blank spaces, and creating variable with name to append to folder containing compiled collection
    string(REGEX REPLACE "[ \t\r\n]" "" CMAKE_GENERATOR_NO_SPACES ${CMAKE_GENERATOR})

    #"install" the source only collection to this indicated folder
    set (COLLECTOR_SRCONLY_CMAKE_INSTALL_PREFIX ${COLLECTOR_INSTALLS}/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}/${CMAKE_BUILD_TYPE}/SRCONLY/${collection_name} )

    if(NOT DEFINED ${collection_name}_DIR )
        FetchContent_Declare(
            ${collection_name}
            SOURCE_DIR                  ${COLLECTOR_SRCONLY_CMAKE_INSTALL_PREFIX}
            GIT_REPOSITORY              ${COLLECTOR_DIR}/${collection_name_hash_appended}
            GIT_TAG                     ${version_tag}
        )
        FetchContent_Populate(
            ${collection_name}    
        )

        
        
        #target_include_directories (${dependent} PRIVATE ${COLLECTOR_CMAKE_INSTALL_PREFIX}/include )#add path of include folder installed by current collection to dependent executable/library
        target_include_directories (${dependent} PRIVATE ${COLLECTOR_SRCONLY_CMAKE_INSTALL_PREFIX} )#add path of include folder installed by current collection to dependent executable/library

        #target_link_directories (${dependent} PRIVATE ${COLLECTOR_CMAKE_INSTALL_PREFIX}/lib)#add path off lib folder installed by current collection to dependent executable/library

        #setting the path to the installed collecction, the folder containing includes and libs
        SET (${collection_name}_DIR "${COLLECTOR_SRCONLY_CMAKE_INSTALL_PREFIX}" )

        #propagate ${collection_name}_DIR to calling scope, ie the main cmakelist
        SET (${collection_name}_DIR ${${collection_name}_DIR} PARENT_SCOPE )

    else()
        message(STATUS "${collection_name}_DIR is DEFINED by something else")
    endif()

endfunction()