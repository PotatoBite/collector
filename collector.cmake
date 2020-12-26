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

#Set variable to let the user choose if use it offline, under is own risk or check online for dependencies.
#Actually it does not take into account if the downloaded folder is broken or not, i think.
set(FRESH_DOWNLOAD on CACHE BOOL "download a fresh copy of all dependencies")

#set the path to downloaded collections and installed collections
SET (COLLECTOR_DIR   ${PROJECT_SOURCE_DIR}/collected_deps)
SET (COLLECTOR_INSTALLS   ${PROJECT_BINARY_DIR}/collected_installs)


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
function(collect collection_name git_url version_tag dependent )
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
        target_include_directories (${dependent} PRIVATE ${COLLECTOR_INSTALLS}/include )
        target_link_directories (${dependent} PRIVATE ${COLLECTOR_INSTALLS}/lib)
        
        #setting the path to the installed collecction, the folder containing includes and libs
        SET (${collection_name}_DIR "${COLLECTOR_INSTALLS}/${collection_name}" )

        #propagate ${collection_name}_DIR to calling scope, ie the main cmakelist
        SET (${collection_name}_DIR ${${collection_name}_DIR} PARENT_SCOPE )

    else()
        message(STATUS "${collection_name}_DIR is DEFINED by something else")
    endif()

endfunction()