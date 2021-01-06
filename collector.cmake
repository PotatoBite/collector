#Collector depends on ExternalProject, is actually a convenience wrapper of it, with some utilities
include(ExternalProject)

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
function(collect git_url version_tag dependent )
    #here we are calculating a name for the downloaded dependency
    string(REGEX MATCH "[^/]+$" temp ${git_url})#getting the name based on the url
    set(collection_name _${temp})#adding _ to the collection name for compatibility with other cmake variables, like lib names when linking

    string(CONCAT temp ${git_url} ${version_tag})# computing has based on url, and tag
    string(SHA1 temp ${temp})
    string(CONCAT collection_name_hash_appended ${collection_name} "-" ${temp})#computing final name of downloaded collection

    #checking if the path to required headers/libs is given by command or sets it's own
    if(COLLECTOR_COLLECT_TOGETHER)
        set (COLLECTOR_CMAKE_INSTALL_PREFIX ${COLLECTOR_INSTALLS}/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION} )
    else()
        set (COLLECTOR_CMAKE_INSTALL_PREFIX ${COLLECTOR_INSTALLS}/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}/${collection_name} )
    endif()

    #checking if the collection is already downloaded
    if(EXISTS "${COLLECTOR_DIR}/${collection_name_hash_appended}/CMakeLists.txt" AND NOT FRESH_DOWNLOAD)
        message("Using cache version of ${collection_name} in folder:  ${collection_name_hash_appended} ")
    else()
        # Define the variable to enable DOWNLOAD step
        set( COLLECTION_REPO GIT_REPOSITORY ${git_url})
        message("The collection ${collection_name} will be downloaded to folder:  ${collection_name_hash_appended} ")
    endif()

    if(NOT DEFINED ${collection_name}_DIR )
        ExternalProject_Add( ${collection_name}
            SOURCE_DIR          ${COLLECTOR_DIR}/${collection_name_hash_appended}
            ${COLLECTION_REPO}
            BINARY_DIR          ${COLLECTOR_DIR}/temp_workbench/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}/${collection_name_hash_appended}
            GIT_TAG             ${version_tag}
            #CONFIGURE_COMMAND   ""
            #BUILD_COMMAND       ""
            #INSTALL_COMMAND     ""
            #INSTALL_DIR         ${COLLECTOR_CMAKE_INSTALL_PREFIX} #don't know what it is used for
            CMAKE_ARGS          ${CL_ARGS} -DCMAKE_INSTALL_PREFIX=${COLLECTOR_CMAKE_INSTALL_PREFIX} -DCOLLECTOR_DIR=${COLLECTOR_DIR} -DCOLLECTOR_INSTALLS=${COLLECTOR_INSTALLS}
        )
        add_dependencies(${dependent} ${collection_name})#wait for the download/configure/build/install of collection
        target_include_directories (${dependent} PRIVATE ${COLLECTOR_CMAKE_INSTALL_PREFIX}/include )#add path off include folder installed by current collection to dependent executable/library
        target_link_directories (${dependent} PRIVATE ${COLLECTOR_CMAKE_INSTALL_PREFIX}/lib)#add path off lib folder installed by current collection to dependent executable/library

        #setting the path to the installed collecction, the folder containing includes and libs
        SET (${collection_name}_DIR "${COLLECTOR_CMAKE_INSTALL_PREFIX}" )

        #propagate ${collection_name}_DIR to calling scope, ie the main cmakelist
        SET (${collection_name}_DIR ${${collection_name}_DIR} PARENT_SCOPE )

    else()
        message(STATUS "${collection_name}_DIR is DEFINED by something else")
    endif()

endfunction()

#Function to setup external projects
#WARNING THIS FUNCTION IS NOT MANTAINED
function(named_collect collection_name git_url version_tag dependent )
    if (FRESH_DOWNLOAD)
        # Define the variable to enable DOWNLOAD step
        set( COLLECTION_REPO GIT_REPOSITORY ${git_url})
    endif()

    #checking if the path to required headers/libs is given by command or sets it's own
    if(COLLECTOR_COLLECT_TOGETHER)
        set (COLLECTOR_CMAKE_INSTALL_PREFIX ${COLLECTOR_INSTALLS} )
    else()
        set (COLLECTOR_CMAKE_INSTALL_PREFIX ${COLLECTOR_INSTALLS}/${collection_name} )
    endif()

    if(NOT DEFINED ${collection_name}_DIR )
        ExternalProject_Add( ${collection_name}
            SOURCE_DIR          ${COLLECTOR_DIR}/${collection_name}
            ${COLLECTION_REPO}
            BINARY_DIR          ${PROJECT_BINARY_DIR}/${collection_name}
            GIT_TAG             ${version_tag}
            #CONFIGURE_COMMAND   ""
            #BUILD_COMMAND       ""
            #INSTALL_COMMAND     ""
            #INSTALL_DIR         ${COLLECTOR_CMAKE_INSTALL_PREFIX} #don't know what it is used for
            CMAKE_ARGS          ${CL_ARGS} -DCMAKE_INSTALL_PREFIX=${COLLECTOR_CMAKE_INSTALL_PREFIX}
        )
        add_dependencies(${dependent} ${collection_name})#wait for the download/configure/build/install of collection
        target_include_directories (${dependent} PRIVATE ${COLLECTOR_CMAKE_INSTALL_PREFIX}/include )#add path off include folder installed by current collection to dependent executable/library
        target_link_directories (${dependent} PRIVATE ${COLLECTOR_CMAKE_INSTALL_PREFIX}/lib)#add path off lib folder installed by current collection to dependent executable/library

        #setting the path to the installed collecction, the folder containing includes and libs
        SET (${collection_name}_DIR "${COLLECTOR_INSTALLS}/${collection_name}" )

        #propagate ${collection_name}_DIR to calling scope, ie the main cmakelist
        SET (${collection_name}_DIR ${${collection_name}_DIR} PARENT_SCOPE )

    else()
        message(STATUS "${collection_name}_DIR is DEFINED by something else")
    endif()

endfunction()