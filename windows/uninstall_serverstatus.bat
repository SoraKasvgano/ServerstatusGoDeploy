@echo off
chcp 65001 >nul 2>&1  :: 强制UTF-8编码，解决中文乱码
setlocal enabledelayedexpansion

:: ===================== 核心配置（与部署脚本保持一致） =====================
set "SERVICE_NAME=ServerStatus"  :: 需与部署脚本的服务名一致
set "LOG_FILE=%SystemRoot%\System32\config\systemprofile\AppData\Local\ServerStatus.log"

:: ===================== 自动识别系统位数 + NSSM路径 =====================
set "NSSM_EXE="
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "NSSM_EXE=%~dp0nssm64.exe"
) else (
    set "NSSM_EXE=%~dp0nssm32.exe"
)

:: ===================== 颜色输出函数 =====================
:color_print
echo %~1
goto :eof

:: ===================== 第一步：检查NSSM文件 =====================
echo.
call :color_print "[94m===== 第一步：检查NSSM工具 =====[0m"
if not exist "!NSSM_EXE!" (
    call :color_print "[91m❌ 错误：未找到NSSM文件！[0m"
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
        call :color_print "[91m请将 nssm64.exe 放在脚本同目录。[0m"
    ) else (
        call :color_print "[91m请将 nssm32.exe 放在脚本同目录。[0m"
    )
    pause
    exit /b 1
)
call :color_print "[92m✅ 检测到NSSM文件：!NSSM_EXE![0m"

:: ===================== 第二步：停止并移除服务 =====================
echo.
call :color_print "[94m===== 第二步：停止并卸载服务 =====[0m"

:: 检查服务是否存在
sc query "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    call :color_print "[93mℹ️ %SERVICE_NAME% 服务不存在，无需卸载。[0m"
    goto :clean_log
)

:: 停止服务
call :color_print "[93mℹ️ 停止 %SERVICE_NAME% 服务...[0m"
"!NSSM_EXE!" stop "%SERVICE_NAME%" >nul 2>&1
timeout /t 1 /nobreak >nul

:: 移除服务
call :color_print "[93mℹ️ 卸载 %SERVICE_NAME% 服务...[0m"
"!NSSM_EXE!" remove "%SERVICE_NAME%" confirm >nul 2>&1
if errorlevel 1 (
    call :color_print "[91m❌ 服务卸载失败！请手动执行：!NSSM_EXE! remove %SERVICE_NAME% confirm[0m"
    pause
    exit /b 1
)
call :color_print "[92m✅ %SERVICE_NAME% 服务已成功卸载。[0m"

:: ===================== 第三步：清理日志文件 =====================
:clean_log
echo.
call :color_print "[94m===== 第三步：清理日志文件 =====[0m"
if exist "%LOG_FILE%" (
    call :color_print "[93mℹ️ 删除日志文件：%LOG_FILE%[0m"
    del /f /q "%LOG_FILE%" >nul 2>&1
    if errorlevel 1 (
        call :color_print "[93m⚠️  日志文件删除失败（可能被占用），请手动删除：%LOG_FILE%[0m"
    ) else (
        call :color_print "[92m✅ 日志文件已清理。[0m"
    )
) else (
    call :color_print "[93mℹ️ 无日志文件需要清理。[0m"
)

:: ===================== 第四步：验证卸载结果 =====================
echo.
call :color_print "[94m===== 第四步：验证卸载结果 =====[0m"
sc query "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    call :color_print "[92m🎉 卸载完成！%SERVICE_NAME% 服务已完全移除。[0m"
) else (
    call :color_print "[91m❌ 卸载不彻底！服务仍存在，请手动执行以下命令：[0m"
    call :color_print "   sc delete %SERVICE_NAME%"
)

echo.
call :color_print "[92m✅ 卸载脚本执行完毕！按任意键退出...[0m"
pause >nul
exit /b 0
