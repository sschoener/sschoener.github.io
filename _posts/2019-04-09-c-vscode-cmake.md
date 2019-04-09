---
layout: post
title: Using cmake/msvc/vscode on Windows in 2019
excerpt: It's suprisingly simple.
tags: [programming, c]
---

I was preparing for a long evening of getting stuff set up on Windows to be able to use a combination of `cmake`, `msvc`, and `vscode`, but it turns out to be super-easy nowadays!

For future reference, here is a quick guide to getting setup in less than 5 minutes (assuming a decent internet connection):
    * Install the [C/CPP extension](https://marketplace.visualstudio.com/itemdetails?itemName=ms-vscode.cpptools) for VSCode.
    * Install the [CMake Tools extension](https://marketplace.visualstudio.com/itemdetails?itemName=vector-of-bool.cmake-tools) for VSCode.
    * Install the [VS2019 build tools](https://visualstudio.microsoft.com/downloads/).
    * Install [CMake](https://cmake.org/download/).
    * Create a new folder with a file `main.cpp` 
      ```cpp
      #include <iostream> 
      int main(int argc, const char * argv[]) {
          std::cout << "It works!" << '\n';
          return 0;
      }
      ```
      and a file `CMakeLists.txt`
      ```
      cmake_minimum_required(VERSION 3.0)
      project(ctest)
      set(SOURCE main.cpp)
      add_executable(${PROJECT_NAME} ${SOURCE})
      ```
    * Hit F7 to run cmake and select the appropriate toolkit when prompted.
    * Optional step: Switch to the debugger in VSCode, add a configuration for `C+++ Windows` with the path to your generated executable. Debugging should now work.
    * Intellisense should mostly work, but if it is complaining about not finding an include, make sure to click the lightbulb to add it to the path. This seems to break down when you are using other compilers, which is what made me give up on clang on Windows for now (I don't care about Intellisense all that much, but always seeing errors for missing includes would drive me nuts).