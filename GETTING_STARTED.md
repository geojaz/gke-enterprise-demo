

# Bazel

## Getting started ##

Follow the instructions at https://docs.bazel.build/versions/master/install.html to install an appropriate version for your OS. I've been successful using MacOS with the binary installer. Apple has you install a few components for Xcode as part of the process, so grant the access and make sure the installer completes successfully. 

Run `bazel version` to make sure that it initializes correctly. Bazel commands should be run from the root of the "WORKSPACE" because it relies heavily on relative pathes. If `bazel version` is run outside a WORKSPACE, it will output the vesion and some metadata, but it will not do much else. 


## WORKSPACE

Set up the workspsace 

a from a directory that is not set up as a Bazel workspace, a few warnings will display, but if the result is something similar to 


## BUILD.bazel

## 

https://www.kchodorow.com/blog/2017/03/27/stamping-your-builds/