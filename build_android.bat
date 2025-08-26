@echo off
REM ==============================================
REM OpenCV Android Build Script
REM ==============================================

REM 修改以下路径为你本机的实际路径,安装了Android Studio之后JAVA_HOME的路径在：C:\Program Files\Android\Android Studio\jbr，需要自己配到环境变量中%JAVA_HOME%\bin
set NDK_PATH=C:/Users/miles/AppData/Local/Android/Sdk/ndk/29.0.13846066
set ANDROID_SDK_PATH=C:/Users/miles/AppData/Local/Android/Sdk

REM 设置源码目录（OpenCV源码根目录，包含CMakeLists.txt的目录）
set SRC_DIR=%~dp0
REM 移除路径末尾的斜杠
set SRC_DIR=%SRC_DIR:~0,-1%

REM 设置构建目录
set BUILD_DIR=%SRC_DIR%\build_android

REM 如果目录已存在则删除
if exist "%BUILD_DIR%" (
    echo Removing old build directory...
    rmdir /s /q "%BUILD_DIR%"
)

REM 创建新的 build 目录
mkdir "%BUILD_DIR%"
cd "%BUILD_DIR%" || (
    echo 无法进入构建目录 %BUILD_DIR%
    pause
    exit /b 1
)

REM 配置环境变量，让CMake能找到Android SDK
set ANDROID_SDK_ROOT=%ANDROID_SDK_PATH%
set ANDROID_HOME=%ANDROID_SDK_PATH%

REM 配置 CMake
cmake -G Ninja ^
 -DCMAKE_TOOLCHAIN_FILE="%NDK_PATH%/build/cmake/android.toolchain.cmake" ^
 -DANDROID_ABI=arm64-v8a ^
 -DANDROID_PLATFORM=android-27 ^
 -DCMAKE_BUILD_TYPE=Release ^
 -DBUILD_SHARED_LIBS=ON ^
 -DBUILD_TESTS=OFF ^
 -DBUILD_PERF_TESTS=OFF ^
 -DBUILD_EXAMPLES=OFF ^
 -DBUILD_ANDROID_PROJECTS=ON ^
 -DANDROID_SDK="%ANDROID_SDK_PATH%" ^
 "%SRC_DIR%"

REM 检查CMake配置是否成功
if %errorlevel% neq 0 (
    echo CMake配置失败!
    pause
    exit /b %errorlevel%
)

REM 编译（使用多线程加速）
cmake --build . --config Release --parallel 8

REM 检查编译是否成功
if %errorlevel% equ 0 (
    echo.
    echo ==============================================
    echo ✅ Build finished successfully!
    echo 输出文件在: %BUILD_DIR%
    echo so 库路径: %BUILD_DIR%/lib/arm64-v8a/
    echo aar 文件路径: %BUILD_DIR%/sdk/android/lib/
    echo ==============================================
) else (
    echo.
    echo ==============================================
    echo ❌ Build failed!
    echo ==============================================
)

pause