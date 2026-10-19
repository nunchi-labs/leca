@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 exit /b 1
rem Nested CMake try_compile reads this from the environment. The cache
rem entry in windows/CMakeLists.txt does not reach those test projects.
set "CMAKE_RC_COMPILER=C:\WinKits\10\bin\10.0.26100.0\x64\rc.exe"
set FLUTTER_ROOT=C:\flutter
set PATH=C:\Users\leca\.cargo\bin;%PATH%
cd /d C:\leca\src
cmd /c C:\flutter\bin\flutter.bat build windows --release --dart-define=AUTH_API=%LECA_AUTH_API%
if not exist C:\leca\src\build\windows\x64\runner\Release\leca.exe exit /b 1
echo LECA_WIN_OK
exit /b 0
