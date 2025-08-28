@echo off
REM ==============================================
REM OpenCV Android build script (produce .so + export headers)
REM ==============================================

setlocal EnableExtensions EnableDelayedExpansion

REM Allow overriding via environment variables; auto-detect if not set
if not defined ANDROID_SDK_PATH set ANDROID_SDK_PATH=%LOCALAPPDATA%/Android/Sdk
if not defined JAVA_HOME set JAVA_HOME=C:/Program Files/Android/Android Studio/jbr

REM Default NDK path (user-specific)
if not defined NDK_PATH set "NDK_PATH=C:\Users\miles\AppData\Local\Android\Sdk\ndk\29.0.13846066"
set "NDK_PATH=C:\Users\miles\AppData\Local\Android\Sdk\ndk\29.0.13846066"


REM Prefer ANDROID_NDK_HOME/ANDROID_NDK_ROOT/NDK_PATH; otherwise pick the newest NDK under SDK
if not defined NDK_PATH (
    if defined ANDROID_NDK_HOME (
        set NDK_PATH=%ANDROID_NDK_HOME%/ndk/29.0.13846066
    ) else if defined ANDROID_NDK_ROOT (
        set NDK_PATH=%ANDROID_NDK_ROOT%/ndk/29.0.13846066
    ) else (
        if exist "%ANDROID_SDK_PATH%\ndk\29.0.13846066" (
            set NDK_PATH=%ANDROID_SDK_PATH%\ndk\29.0.13846066
        )
    )
)

set SRC_DIR=%~dp0
set SRC_DIR=%SRC_DIR:~0,-1%
set BUILD_DIR=%SRC_DIR%\build_android
set INSTALL_DIR=%SRC_DIR%\opencv_android_3rd

REM Allow multiple ABIs via ANDROID_ABIS (space-separated), default to arm64-v8a
if not defined ANDROID_ABIS set ANDROID_ABIS=arm64-v8a

if exist "%BUILD_DIR%" (
    echo [1/5] Cleaning previous build directory...
    rmdir /s /q "%BUILD_DIR%"
)
if exist "%INSTALL_DIR%" (
    echo [1/5] Cleaning previous install directory...
    rmdir /s /q "%INSTALL_DIR%"
)
mkdir "%BUILD_DIR%"
cd "%BUILD_DIR%" || (
    echo Error: Cannot enter build directory %BUILD_DIR%
    pause
    exit /b 1
)

echo [2/5] Setting up environment variables...
set ANDROID_SDK_ROOT=%ANDROID_SDK_PATH%
set ANDROID_HOME=%ANDROID_SDK_PATH%
set PATH=%JAVA_HOME%\bin;%PATH%

java -version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Java not found. Please check JAVA_HOME!
    pause
    exit /b 1
)

echo NDK_PATH=%NDK_PATH%
if not exist "%NDK_PATH%\build\cmake\android.toolchain.cmake" (
    echo Error: Toolchain file not found:
    echo   "%NDK_PATH%\build\cmake\android.toolchain.cmake"
    echo Please set NDK_PATH or ANDROID_NDK_HOME to a valid NDK directory.
    if not defined NONINTERACTIVE pause
    exit /b 1
)

for %%A in (%ANDROID_ABIS%) do (
    echo [3/5] Running CMake configure - ABI=%%A...
    if not exist "%%A" mkdir "%%A"
    cd "%%A" || (
        echo Error: Cannot enter sub-build directory %BUILD_DIR%\%%A
        exit /b 1
    )

    cmake -G Ninja ^
     -DCMAKE_TOOLCHAIN_FILE="%NDK_PATH%/build/cmake/android.toolchain.cmake" ^
     -DANDROID_ABI=%%A ^
     -DANDROID_PLATFORM=android-27 ^
     -DCMAKE_BUILD_TYPE=Release ^
     -DBUILD_SHARED_LIBS=ON ^
     -DBUILD_TESTS=OFF ^
     -DBUILD_PERF_TESTS=OFF ^
     -DBUILD_EXAMPLES=OFF ^
     -DBUILD_ANDROID_PROJECTS=OFF ^
     -DANDROID_SDK="%ANDROID_SDK_PATH%" ^
     -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" ^
     -DCMAKE_INSTALL_LIBDIR=lib/%%A ^
     "%SRC_DIR%"

    if errorlevel 1 (
        echo Error: CMake configure failed - ABI=%%A! Please check paths or dependencies.
        exit /b 1
    )

    echo [4/5] Building OpenCV - ABI=%%A, parallel...
    cmake --build . --config Release --parallel 8

    if errorlevel 1 (
        echo Error: OpenCV build failed - ABI=%%A!
        exit /b 1
    )

    echo [5/5] Installing export headers and .so - ABI=%%A...
    cmake --build . --config Release --target install

    if errorlevel 1 (
        echo Error: Install/export failed - ABI=%%A!
        exit /b 1
    )

    cd "%BUILD_DIR%"
)

echo [6/5] Preparing simplified install layout...
if not exist "%INSTALL_DIR%\include\opencv2" (
    mkdir "%INSTALL_DIR%\include\opencv2" 2>nul
    xcopy /E /I /Y "%INSTALL_DIR%\sdk\native\jni\include\opencv2" "%INSTALL_DIR%\include\opencv2\" >nul
)
for %%A in (%ANDROID_ABIS%) do (
    if not exist "%INSTALL_DIR%\lib\%%A" mkdir "%INSTALL_DIR%\lib\%%A" 2>nul
    xcopy /Y "%INSTALL_DIR%\sdk\native\libs\%%A\*.so" "%INSTALL_DIR%\lib\%%A\" >nul
)

echo.
echo ==============================================
echo All ABIs built and installed successfully.
echo Output directory: %INSTALL_DIR%
echo --------------------------
echo SDK layout:
echo %INSTALL_DIR%\sdk\native\jni\include\opencv2\
for %%A in (%ANDROID_ABIS%) do echo %INSTALL_DIR%\sdk\native\libs\%%A\
echo Simplified layout:
echo %INSTALL_DIR%\include\opencv2\
for %%A in (%ANDROID_ABIS%) do echo %INSTALL_DIR%\lib\%%A\
echo ==============================================
echo Integrate into your A.so/JNI project:
echo 1. Copy %INSTALL_DIR%\include\opencv2\ to 3rd\opencv\include\
echo 2. Copy %INSTALL_DIR%\lib\[abi]\*.so to 3rd\opencv\lib\[abi]\
echo 3. In CMakeLists.txt:
echo    - include_directories(3rd/opencv/include)
echo    - link_directories(3rd/opencv/lib/[abi])
echo    - target_link_libraries(A.so opencv_core opencv_imgproc ...)
echo ==============================================

if not defined NONINTERACTIVE pause