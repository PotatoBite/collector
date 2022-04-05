This project is closed due a design flaw that will prevent us to achieve our goals( i.e: hard to manage tangled dependencies ) and we though could be easily fixed but ultimately decided to start a fresh project with a better design and probably independency of cmake. 

Use only in small non very extendible projects or for fast prototyping. 

# collector


Mini dependency manager for cmake based projects, is currently just a commodity wrapper( with some automation) of cmake's `ExternalProject_Add` and `FetchContent`, but this will change in the future.

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

Collector right now depends on `ExternalProject` and `FetchContent`, so be sure your cmake supports them. That aside, in your project's `CMakeLists.txt`, you only need to include the `collector.cmake` AFTER the `project()` call:

```cmake
cmake_minimum_required(VERSION 3.11.0)

project(myapp VERSION 0.1.0)

include("collector/collector.cmake")#need to be after project()
```

This is required because collector sets up some variables, (like the cache variable `FRESH_DOWNLOAD`), and need to get some other defined after the call to `project()`, (like `PROJECT_SOURCE_DIR` and `PROJECT_BINARY_DIR` ).



### Collect

The core of collector is the `collect()` function, it does configure all things needed to download, update, configure, build and install each collection.

```cmake
collect( <git_url> <version_tag> <dependant> )
```

It accepts the url of a git repository from where it will clone the desired collection, a tag name, that tells which commit will be used, and the `dependant`, which is the target that will depend on the collection(Of course because there is no way of knowing what target cmake is working on, it must be specified this way, resulting in the call must to be done after `add_executable()` or `add_library()`), for example:

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

### Collect and find
You can use cmake's `find_package()` as in any other project of course, but if the package is installed by one of the collected collection, this will not work, because the collections are compiled and installed on the project's build step, in general any package can be used without getting it with  `find_package()`, however this is a handy feature, so there is a hacky macro for that:

```cmake
collect_and_find( <package_name> <git_url> <version_tag> <dependant> )
```



This is an example using SDL2 library:

```cmake
collect_and_find( SDL2 "https://github.com/libsdl-org/SDL" "release-2.0.14" myapp )
if(${SDL2_FOUND})
	target_link_libraries (myapp PRIVATE SDL2::SDL2main SDL2::SDL2-static )
endif()
```

 That normally( without collector) would be:

```cmake
find_package(SDL2)
if(${SDL2_FOUND})
	target_link_libraries (myapp PRIVATE SDL2::SDL2main SDL2::SDL2-static )
endif()
```

So this shows pretty much the basic stuff, although, the app should compile easily with clang, gcc or mingw, but with msvc if the SDL2 package is missing, the first build installs it along other dependencies and the build needs to be triggered a second time for the main app to be able to find deps and link correctly, cause the first try fails. All this is because some hacky workaround with a `Rescan` custom target .

Again it is really basic, and not supporting things like `find_package(SDL2 REQUIRED) `etc.(not needed though) , but works ok with almost any case like described.


### Collect Source Only 

To download source only dependencies use `collect_src()` function. It does uses cache but store downloaded collection in a slightly different convention, for example is not affected by the use of [COLLECTOR_COLLECT_TOGETHER](#COLLECTOR_COLLECT_TOGETHER).

```cmake
collect_src( <git_url> <version_tag> <dependant> )
```

This works pretty much like `collect()`(See [Collect](#Collect) for examples and better understanding), so use the same instructions, maybe main difference is implementation, and right now `collect()` is using cmake's `ExternalProject_Add`, and `collect_src()` is using `FetchContent_Declare` and `FetchContent_Populate`.

This also does not trigger any build, just copies the repo verbatim.

```cmake
add_executable(myapp main.cpp)

collect_src( "https://github.com/PotatoBite/xgetopt.git" "v1.0.0" myapp)
```

Ending with an structure in installed collections folder like this:
```bash
├───GNU-9.2.0
│   └───RelWithDebInfo
│       ├───bin
│       ├───cmake
│       ├───include
│       │   ├───fritters
│       │   ├───SDL2
│       │   └───spdlog
│       ├───lib
│       └───SRCONLY
│           ├───_glm.git
│           ├───_xgetopt.git
│           └───_googletest.git
```



Also, collector automatically adds the repos folders (the ones under `SRCONLY`) of each installed collection to the `include_directories ` of selected target. 

Right now there is no way to call `collect_src` before `add_executable` or `add_library` and use downloaded source files inside them, in future releases will be possible, but for now, yo can add downloaded source files to the target with cmake's `target_sources`, like this:

```cmake
target_sources(myapp
  PRIVATE "xgetopt.c"
  PRIVATE "googletest/src/gtest.cc"
)
```





### Cache

By default collector store the downloaded collections in the folder pointed by `COLLECTOR_DIR`, this is a cache variable, so can be set by  set by cmake-gui, passing its value by command, or directly on code.(refer to [FRESH_DOWNLOAD](#FRESH_DOWNLOAD) for examples).

If `COLLECTOR_DIR` variable is not defined manually, collector will use an environment variable(`COLLECTOR_CACHE_ROOT`) , which is the recommended way, cause is storing global cache of collections. 

If none of the above options, collector fallbacks to create a directory(`collected_deps`) on project root directory(the cmake variable `PROJECT_SOURCE_DIR`).

### Activate options on collections

Because some collections need some tuning to use properly, there is a function to forward custom vars as command line arguments to the invocation of cmake steps on each collection:

```cmake
append_var_to_cmake_args(<CMAKE_VAR>)
```

Example using Glad library:

```cmake
set(GLAD_INSTALL ON)
set(GLAD_NO_LOADER ON)
append_var_to_cmake_args(GLAD_INSTALL)
append_var_to_cmake_args(GLAD_NO_LOADER)
collect( "https://github.com/Dav1dde/glad" "v0.1.34" myapp )
```

This however sends all vars  passed to `append_var_to_cmake_args()` to each collection, meaning in some cases can be unintended behaviors due to clashes between vars names in different collections.

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
  └── GNU-9.2.0
  	└───RelWithDebInfo
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
  └── GNU-9.2.0
  	└───RelWithDebInfo
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


## Notes

- As this is a work in progress, there is no consideration in file sizes, meaning all versions of collections are stored in cache as full repos, and compiled cache contains as many compilations as compilers, generators and configurations used(i.e: one for msvc in Release mode, but also one for msvc in Debug, and also one for clang using unix makefiles  in MinSizeRelease, etc.). Also the source only collections are copied as full repos to its corresponding folder:

  ```cmake
  ${COLLECTOR_INSTALLS}/${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}/${CMAKE_BUILD_TYPE}/SRCONLY/${collection_name}
  ```
  
  for example `./collections/GNU-9.2.0/RelWithDebInfo/SRCONLY/_glm.git`
  
- As in general this is heavily WIP, any issue is recommended to clean build folder(delete entirely if possible) and reconfigure and build project from scratch, in extreme cases if not sure what's happening, delete compiled collections  [Cache](#Cache) folder, which is in `COLLECTOR_DIR/temp_workbench` or `COLLECTOR_ROOT_DIR/temp_workbench`.

- If present errors getting the collection with `collect_src`, maybe is due to the existence of desired collection cache folder(then it thinks is already downloaded), but empty, delete that folder and reconfigure, it should work, is a silly issue, but is not fixed yet.

  (i.e:  `_glm.git-de3fcf281e072987ecc7e2b04407eee428cf8e83 ` folder) 

- Because `collect()` is using cmake's  `ExternalProject_Add`, the git url in argument can be some path to local git repository, a little handy feature not widely known by newbies, like me. 
  
  

## Future

This module was conceived for internal use due to the lack of a: light, offline friendly, powerful, cmake friendly, not biased and standardized dependency manager for c/c++, and is in development, for more mature tools please refer to any of this awesome, but not suitable for us, tools:

- [vcpkg](https://github.com/Microsoft/vcpkg)
- [hunter](https://github.com/cpp-pm/hunter)
- [build2 (toolchain)](https://www.build2.org/)
- [conan](https://conan.io/)

## List of tested collections

This is **NOT** an extensive list, just because **ANY** repository that is cmake configurable, buildable and installable, can be collected and used just like that, thanks to the awesomeness of cmake. This is however a list of some collections previously used successfully, feel free to PR and extend list:

| Collection      | git_url                                        | version_tag    | Notes                                                        |
| --------------- | ---------------------------------------------- | -------------- | ------------------------------------------------------------ |
| Sol2            | https://github.com/ThePhD/sol2                 | v3.2.2         |                                                              |
| spdlog          | https://github.com/gabime/spdlog               | v1.8.5         |                                                              |
| Fritters        | https://github.com/PotatoBite/fritters         | v0.0.15        |                                                              |
| Lua             | https://github.com/daroxs95/Lua                | v5.4.2-install | Cmake based build for lua, fork of [this](https://github.com/walterschell/Lua) with added install step |
| SDL2            | https://github.com/libsdl-org/SDL              | release-2.0.14 | Recommend to use like `collect_and_find(SDL2 <...>)`         |
| Curl            | https://github.com/curl/curl                   | curl-7_79_1    | Recommend to use like `collect_and_find(CURL<...>)`, but not extensively tested |
| Glad            | https://github.com/Dav1dde/glad                | v0.1.34        |                                                              |
| jsoncpp         | https://github.com/open-source-parsers/jsoncpp | 1.9.4          |                                                              |
| Tuberosum Tools | https://github.com/PotatoBite/tuberosum_tools  | v1.0.3         | For now is a private repo, is here for future public release |
| Rpt reader      | https://github.com/PotatoBite/rpt_reader       | v0.0.1         | For now is a private repo, is here for future public release |
| Civ             | https://github.com/PotatoBite/civ              | v1.0.4         | For now is a private repo, is here for future public release |
| xgetopt         | https://github.com/PotatoBite/xgetopt          | v1.0.0         | Cmake based build for xgetopt, fork of [this](https://github.com/matthklo/xgetopt) |

