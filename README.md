# collector

* TOC
{:toc}


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

You can just include the file `collector.cmake` in your project, but we strongly recommend using it as a submodule.

```bash
git submodule add https://github.com/PotatoBite/collector
```

Collector right now depends on `ExternalProject`, so be sure your cmake supports it. That aside, in your project's `CMakeLists.txt`, you only need to include the `collector.cmake` AFTER the `project()` call:

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

It accepts the url of a git repository from where it will clone the desired collection, a tag name, that tells which commit will be used, and the `dependent`, which is the target that will depend on the collection(Of course because there is no way of knowing what target cmake is working on, it must be specified this way, resulting in the call must to be done after `add_executable()` or `add_library()`), for example:

```cmake
add_executable(myapp main.cpp)

collect( "https://github.com/PotatoBite/xgetopt" "v1.0.0" myapp)
```

Also, collector automatically adds the folders `include` and `lib` of each installed collection to the `include_directories ` and `link_directories` of selected target, making a very clean `CMakeLists.txt`, and easy way of using cmake and dependencies, for example, this is a fully working cmake project:

```cmake
cmake_minimum_required(VERSION 3.0.0)

project(myproject.myapp VERSION 0.1.0)

include("collector/collector.cmake")#need to be after project()

include(CTest)

enable_testing()

set (CMAKE_CXX_STANDARD 17)

add_executable(myapp main.cpp)

collect( "https://github.com/open-source-parsers/jsoncpp" "1.9.4" myapp)
collect( "https://github.com/PotatoBite/xgetopt" "v1.0.0" myapp)

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})

include(CPack)

target_link_libraries (myapp PRIVATE jsoncpp_static xgetopt )

install(TARGETS myapp DESTINATION "bin")
```

### Cache

By default collector store the downloaded collections in the folder pointed by `COLLECTOR_DIR`, this is a cache variable, so can be set by  set by cmake-gui, passing its value by command, or directly on code.(refer to [FRESH_DOWNLOAD](#FRESH_DOWNLOAD) for examples).

If `COLLECTOR_DIR` variable is not defined manually, collector will use an environment variable(`COLLECTOR_CACHE_ROOT`) , which is the recommended way, cause is storing global cache of collections. 

If none of the above options, collector fallbacks to create a directory(`collected_deps`) on project root directory(the cmake variable `PROJECT_SOURCE_DIR`).



## Advanced

### Compiler selection and options forwarding

By default collector forwards the selected kit of your project to the collections, meaning all will be compiled with the same  kit and will be consistent. Currently there is no interface to communicate to collector and tune compiler kit for each collection individually(and probably is a bad idea in most cases), but will be soon.

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

This variable is accessible from cmake's cache and it's `off` by default. It can be set by cmake-gui, passing its value by command, or directly on code :

- command line:

  ```bash
  cmake -B build/ -DFRESH_DOWNLOAD=off
  ```

- CMakeLists.txt:

  ```cmake
  #set(FRESH_DOWNLOAD on)#Not recommended
  ```

Although this is just for rare cases, because is tampering the real cache variable with same name, and overriding the custom collector behavior for caching collections :

- `on`: collector will try to download all collections even if they are in cache(does not triggers a download step if the project was previously configured and builded, if not, it will erase and re-download each collection), 
- `off`: `default`, if you have the collections previously downloaded to the folder `COLLECTOR_DIR`(in cache), the build process will go smoothly, even if offline, but if there is missing collections, it will try to download.

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
collect( "https://github.com/PotatoBite/xgetopt" "v1.0.0" myapp)

message( "path to collection xgetopt= ${_xgetopt_DIR}")
```

You can also get it when `collect_together` but all variables will point to the same path.

The naming of the variable is: (`"_"`) + (the last string after `/` in the url) + (`"_DIR"`).

## Future

This module was conceived for internal use due to the lack of a: light, offline friendly, powerful, cmake friendly, not biased and standardized dependency manager for c/c++, and is in development, for more mature tools please refer to any of this awesome, but not suitable for us, tools:

- [vcpkg](https://github.com/Microsoft/vcpkg)
- [hunter](https://github.com/cpp-pm/hunter)
- [build2 (toolchain)](https://www.build2.org/)
- [conan](https://conan.io/)



