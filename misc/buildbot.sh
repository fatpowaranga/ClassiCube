#!/bin/bash

# These build instructions are for ubuntu. Other linux distributions may have saner behaviour.
# The build script relies on the following assumptions:
# - You have already cloned ClassiCube from github
# - The root folder is ~/client/ (i.e. folder layout is ~/client/.git/, ~/client/src/, etc)
# First you need to install these packages: gcc, i686-w64-mingw32-gcc and x86_64-w64-mingw32-gcc
# 
# You then need to install these packages: libx11-dev, libgl1-mesa-dev, libopenal-dev, libcurl4-gnutls-dev/libcurl4-openssl-dev
# - if 32 bit, then install the 64 bit variants of all these packages (e.g. libx11-dev:amd64)
# - if 64 bit, then install the 32 bit variants of all these packages (e.g. libx11-dev:i386)
#
# However! You may find that installing the alternate bit variant of libgl1-mesa-dev uninstalls your current package
# To fix this, first reinstall the normal libgl1-mesa-dev package
# The alternate bit .so files should have been left behind in the mesa folder, so adding a symlink should make it compile again
# - for 32 bit: ln -sf /usr/lib/x86_64-linux-gnu/mesa/libGL.so.1 /usr/lib/x86_64-linux-gnu/libGL.so
# - for 64 bit: ln -sf /usr/lib/i386-linux-gnu/mesa/libGL.so.1 /usr/lib/i386-linux-gnu/libGL.so
#
# You should now be able to compile both 32 and 64 bit variants of the client for linux
# However! The default libcurl package will produce an executable that won't run on Arch (due to defining CURL_OPENSSL_3)
# As such, you may want to uninstall libcurl package, manually compile curl's source code for both 32 and 64 bit, 
# then add the .so files to /usr/lib/i386-linux-gnu and /usr/lib/x86_64-linux-gnu/

# change these as needed
SOURCE_DIR=~/client
EMSCRIPTEN_PATH=/usr/bin/emscripten/emcc
CLANG32_PATH=/usr/bin/clang/osx32
CLANG64_PATH=/usr/bin/clang/osx64
# to simplify stuff
ALL_FLAGS="-O1 -s -fno-stack-protector -fno-math-errno -w"
WIN32_FLAGS="-mwindows -nostartfiles -Wl,-e_main_real -DCC_NOMAIN"
WIN64_FLAGS="-mwindows -nostartfiles -Wl,-emain_real -DCC_NOMAIN"

# -----------------------------
build_win32() {
  echo "Building win32.."
  cp $SOURCE_DIR/misc/CCicon_32.res $SOURCE_DIR/src/CCicon_32.res
  rm cc-w32-d3d.exe cc-w32-ogl.exe

  i686-w64-mingw32-gcc *.c $ALL_FLAGS $WIN32_FLAGS -o cc-w32-d3d.exe CCicon_32.res -DCC_COMMIT_SHA=\"$LATEST\" -lws2_32 -lwininet -lwinmm -limagehlp -lcrypt32 -ld3d9
  i686-w64-mingw32-gcc *.c $ALL_FLAGS $WIN32_FLAGS -o cc-w32-ogl.exe CCicon_32.res -DCC_COMMIT_SHA=\"$LATEST\" -DCC_BUILD_MANUAL -DCC_BUILD_WIN -DCC_BUILD_GL -DCC_BUILD_WINGUI -DCC_BUILD_WGL -DCC_BUILD_WINMM -DCC_BUILD_WININET -lws2_32 -lwininet -lwinmm -limagehlp -lcrypt32 -lopengl32
}

build_win64() {
  echo "Building win64.."
  cp $SOURCE_DIR/misc/CCicon_64.res $SOURCE_DIR/src/CCicon_64.res
  rm cc-w64-d3d.exe cc-w64-ogl.exe
  
  x86_64-w64-mingw32-gcc *.c $ALL_FLAGS $WIN64_FLAGS -o cc-w64-d3d.exe CCicon_64.res -DCC_COMMIT_SHA=\"$LATEST\" -lws2_32 -lwininet -lwinmm -limagehlp -lcrypt32 -ld3d9
  x86_64-w64-mingw32-gcc *.c $ALL_FLAGS $WIN64_FLAGS -o cc-w64-ogl.exe CCicon_64.res -DCC_COMMIT_SHA=\"$LATEST\" -DCC_BUILD_MANUAL -DCC_BUILD_WIN -DCC_BUILD_GL -DCC_BUILD_WINGUI -DCC_BUILD_WGL -DCC_BUILD_WINMM -DCC_BUILD_WININET -lws2_32 -lwininet -lwinmm -limagehlp -lcrypt32 -lopengl32
}

build_nix32() {
  echo "Building linux32.."
  rm cc-nix32
  gcc *.c $ALL_FLAGS -fvisibility=hidden -rdynamic -DCC_COMMIT_SHA=\"$LATEST\" -m32 -o cc-nix32 -lX11 -lpthread -lGL -lm -lcurl -lopenal -ldl
}

build_nix64() {
  echo "Building linux64.."
  rm cc-nix64
  gcc *.c $ALL_FLAGS -fvisibility=hidden -rdynamic -DCC_COMMIT_SHA=\"$LATEST\" -m64 -o cc-nix64 -lX11 -lpthread -lGL -lm -lcurl -lopenal -ldl
}

build_osx32() {
  echo "Building mac32.."
  rm cc-osx32
  $CLANG32_PATH *.c $ALL_FLAGS -fvisibility=hidden -rdynamic -DCC_COMMIT_SHA=\"$LATEST\" -o cc-osx32 -framework Carbon -framework AGL -framework OpenAL -framework OpenGL -lcurl
}

build_osx64() {
  echo "Building mac64.."
  rm cc-osx32
  $CLANG64_PATH *.c $ALL_FLAGS -fvisibility=hidden -rdynamic -DCC_COMMIT_SHA=\"$LATEST\" -o cc-osx64 -framework Cocoa -framework OpenAL -framework OpenGL -lcurl -lobjc
}

build_web()  {
  echo "Building web.."
  rm cc.js
  $EMSCRIPTEN_PATH *.c -O1 -o cc.js -s FETCH=1 -s WASM=0 -s ALLOW_MEMORY_GROWTH=1 --preload-file texpacks/default.zip -w
  # so game loads textures from classicube.net/static/default.zip
  sed -i 's#cc.data#/static/default.zip#g' cc.js
  # fix texture pack overlay always showing 'Download size: Determining..."
  sed -i 's#xhr.onload = function(e) {#xhr.onload = function(e) { Fetch.setu64(fetch + 32, e.total);#g' cc.js
  # fix mouse wheel scrolling page not being properly prevented
  # "[Intervention] Unable to preventDefault inside passive event listener due to target being treated as passive."
  sed -i 's#eventHandler.useCapture);#{ useCapture: eventHandler.useCapture, passive: false });#g' cc.js
}

# -----------------------------
cd $SOURCE_DIR/src/
echo $PWD
git pull https://github.com/UnknownShadow200/ClassiCube.git
git fetch --all
git reset --hard origin/master
LATEST=`git rev-parse --short HEAD`

build_win32
build_win64
build_nix32
build_nix64
build_osx32
build_osx64
build_web