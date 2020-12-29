# collector
Mini dependency manager for cmake based projects, is currently just a commodity wrapper( with some automation) of cmake's `ExternalProject_Add`, but this will change in the future.

For total compatibility with all projects, the collections(the dependencies) are assumed to be cmake configurable, buildable, and installable in a folder structure like this:

```bash
.
├── bin
│   └── civ
├── include
│   ├── json
│   ├── tuberosum_tools
│   └── xgetopt.h
└── lib
    ├── cmake
    ├── libjsoncpp.so -> libjsoncpp.so.24
    ├── libjsoncpp.so.1.9.4
    ├── libjsoncpp.so.24 -> libjsoncpp.so.1.9.4
    ├── libjsoncpp_static.a
    ├── libxgetopt.a
    ├── objects-Release
    └── pkgconfig

```



## How to use

### Install

You can just include the file `collector.cmake`, but we strongly recommend using it as a submodule.

```bash
git submodule add https://github.com/PotatoBite/collector
```

Collector right now depends on `ExternalProject`, so be sure your cmake supports it. That aside, in your project's `CMakeLists.txt`, you need to include the `collector.cmake` AFTER the `project()` call:

```cmake
cmake_minimum_required(VERSION 3.0.0)

project(myapp VERSION 0.1.0)

include("collector/collector.cmake")#need to be after project()
```

This is required because collector sets up some variables, (like the cache variable `FRESH_DOWNLOAD`), and need to get some other defined after the call to `project()`, (like `PROJECT_SOURCE_DIR` and `PROJECT_BINARY_DIR` ).

### Collect

The core of collector is the `collect()` function, it does configure all things needed to download, update, configure, build and install each collection.

```cmake
collect( <git_url> <version_tag> <dependent> )
```

It accepts the url of the git repository from it will clone the desired collection, a tag name, that tells which commit will be used, and the `dependent`, which is the target that will depend on the collection(Of course because there is no way of knowing what target cmake is working on, it must be specified this way, resulting in the call must to be done after `add_executable()` or `add_library()`), for example:

```cmake
add_executable(myapp main.cpp)

collect( "https://github.com/PotatoBite/xgetopt" "v1.0.0" myapp)
```

Also, collector automatically adds the folders `include` and `lib` of each installed collection to the `include_directories ` and `link_directories`, of selected target, making a very clean `CMakeLists.txt`, and easy way of using cmake and dependencies, for example, this is a fully working cmake project:

```cmake
cmake_minimum_required(VERSION 3.0.0)

project(myproject.myapp VERSION 0.1.0)

include("collector/collector.cmake")#need to be after project()

include(CTest)

enable_testing()

set (CMAKE_CXX_STANDARD 17)

add_executable(myapp main.cpp)

collect( "https://github.com/open-source-parsers/jsoncpp" "1.9.4" civ)
collect( "https://github.com/PotatoBite/xgetopt" "v1.0.0" civ)

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})

include(CPack)

target_link_libraries (myapp PRIVATE jsoncpp_static xgetopt )

install(TARGETS myapp DESTINATION "bin")
```





## Advanced

### Compiler selection and options forwarding

By default collector forwards the selected kit of your project to the collections, meaning all will be compiled with the same  kit and will be consistent. Currently there is no interface to communicate to collector and tune compiler kit of each collection individually(and probably is a bad idea in most cases), but will be soon.

In fact collector forwards to collections all cache variables declared before it, like:

```cmake
CMAKE_BUILD_TYPE
CMAKE_CXX_COMPILER
CMAKE_C_COMPILER
CMAKE_EXPORT_COMPILE_COMMANDS
```

And some other, not cache, for the correct execution of collector instances in collections:

```cmake
COLLECTOR_DIR				#path to downloaded collections(cloned) folder
COLLECTOR_INSTALLS			#path to installed collections(after compiled) folder
```



### FRESH_DOWNLOAD

This variable is accessible for cache and it's `on` by default. It can be set by cmake-gui, or passing its value by command:

```bash
cmake -B build/ -DFRESH_DOWNLOAD=off
```

 Or directly on code, although this is just for testing purposes, because is overwriting the real cache variable:

```cmake
#set(FRESH_DOWNLOAD off)#this is for compiling locally, but is not recommended, cause is tampering the behavior of the cache variable with the same name
```

When this variable is `off`, if you have the collections previously downloaded to the folder `COLLECTOR_DIR`, the build process will go smoothly, even if offline, but if there is missing collections, it will raise an error.

### COLLECTOR_COLLECT_TOGETHER 

This is another cache variable accessible by cmake-gui, code, and parameter in console/terminal.

But it can be safely turn `on`/`off` with the functions `collect_together()` and `collect_apart()`.

It only affects the installation method of the collections, meaning all collections will be installed on the same path, or in separated folders for each collection. Currently we are only improving the case `on` but when `off`, all should go smoothly,  ie:

- collected_installs folder when collect apart:

  ```bash
  .
  └── GNU-9.3.0
      ├── _jsoncpp
      │   ├── include
      │   └── lib
      ├── _tuberosum_tools
      │   └── include
      └── _xgetopt
          ├── include
          └── lib
  ```

- collected_installs folder when collect together:

  ```bash
  .
  └── GNU-9.3.0
      ├── include
      └── lib
  
  ```

  

for the case of `collect_apart`, you can also get the path to installation folder of each collection by the exported variables, like :

```cmake
collect( "https://github.com/PotatoBite/xgetopt" "v1.0.0" civ)

message("path to collection xgetopt= ${_xgetopt_DIR}")
```

You can also get it when `collect_together` but all will be the same.

The naming of the variable is: (`"_"`) + (the last string after `/` in the url) + (`"_DIR"`).

## 

## Future

This module was conceived for internal use due to the lack of a: light, offline friendly, powerful, cmake friendly, not biased and standardized dependency manager for c/c++, and is in development, for more mature tools please refer to any of this awesome, but not suitable for us, tools:

- vcpkg
- hunter
- build2 (toolchain)
- conan



