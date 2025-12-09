@echo off
chcp 65001 >nul 2>&1  :: 强制UTF-8编码，解决中文乱码
setlocal enabledelayedexpansion

:: ===================== 核心配置（可按需修改） =====================
set "SERVICE_NAME=ServerStatus"  :: 系统服务名（建议英文）
set "PROG_NAME=serverstatus.exe" :: 程序文件名（需与脚本同目录）
:: 日志文件路径（系统服务权限可写）
set "LOG_FILE=%SystemRoot%\System32\config\systemprofile\AppData\Local\ServerStatus.log"

:: ===================== 自动识别系统位数 + NSSM路径 =====================
set "NSSM_EXE="
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    :: 64位系统，调用同目录的nssm64.exe
    set "NSSM_EXE=%~dp0nssm64.exe"
) else (
    :: 32位系统，调用同目录的nssm32.exe
    set "NSSM_EXE=%~dp0nssm32.exe"
)

:: ===================== 颜色输出函数 =====================
:color_print
echo %~1
goto :eof

:: ===================== 第一步：检查依赖文件 =====================
echo.
call :color_print "[94m===== 第一步：检查依赖文件 =====[0m"

:: 检查serverstatus.exe是否存在
if not exist "%PROG_NAME%" (
    call :color_print "[91m❌ 错误：当前目录未找到 %PROG_NAME%！[0m"
    call :color_print "[91m请将脚本与 %PROG_NAME% 放在同一目录后重试。[0m"
    pause
    exit /b 1
)

:: 检查NSSM是否存在
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

call :color_print "[92m✅ 检测到程序文件：%cd%\%PROG_NAME%[0m"
call :color_print "[92m✅ 检测到NSSM文件：!NSSM_EXE![0m"

:: ===================== 第二步：交互式输入运行参数 =====================
echo.
call :color_print "[94m===== 第二步：输入运行参数 =====[0m"
set "DSN_PARAM="
set /p "DSN_PARAM=请输入 -dsn 后的完整参数（示例：Router1.42:pass@192.168.1.40:35601）："

:: 校验参数非空
if "!DSN_PARAM!"=="" (
    call :color_print "[91m❌ 错误：运行参数不能为空！[0m"
    pause
    exit /b 1
)
set "ARGS=-dsn !DSN_PARAM!"
call :color_print "[92m✅ 已获取运行参数：%ARGS%[0m"

:: ===================== 第三步：管理系统服务 =====================
echo.
call :color_print "[94m===== 第三步：注册并配置系统服务 =====[0m"

:: 停止并移除旧服务（如果存在）
call :color_print "[93mℹ️ 清理旧服务配置（如有）...[0m"
"!NSSM_EXE!" stop "%SERVICE_NAME%" >nul 2>&1
"!NSSM_EXE!" remove "%SERVICE_NAME%" confirm >nul 2>&1

:: 注册新服务（核心：指定程序路径+参数）
call :color_print "[93mℹ️ 注册 %SERVICE_NAME% 系统服务...[0m"
"!NSSM_EXE!" install "%SERVICE_NAME%" "%cd%\%PROG_NAME%" "%ARGS%" >nul 2>&1
if errorlevel 1 (
    call :color_print "[91m❌ 错误：服务注册失败！[0m"
    pause
    exit /b 1
)

:: 配置服务高级参数（日志、自启、重启策略）
call :color_print "[93mℹ️ 配置服务运行参数...[0m"
:: 日志重定向（标准输出/错误写入日志文件）
"!NSSM_EXE!" set "%SERVICE_NAME%" AppStdout "%LOG_FILE%" >nul 2>&1
"!NSSM_EXE!" set "%SERVICE_NAME%" AppStderr "%LOG_FILE%" >nul 2>&1
:: 日志轮转（避免日志过大）
"!NSSM_EXE!" set "%SERVICE_NAME%" AppRotateFiles 1 >nul 2>&1
"!NSSM_EXE!" set "%SERVICE_NAME%" AppRotateBytes 10485760 >nul 2>&1 :: 10MB轮转
:: 开机自启
"!NSSM_EXE!" set "%SERVICE_NAME%" Start SERVICE_AUTO_START >nul 2>&1
:: 程序崩溃后自动重启（3秒延迟）
"!NSSM_EXE!" set "%SERVICE_NAME%" AppRestartDelay 3000 >nul 2>&1

:: ===================== 第四步：启动服务并验证 =====================
echo.
call :color_print "[94m===== 第四步：启动服务并验证 =====[0m"
call :color_print "[93mℹ️ 启动 %SERVICE_NAME% 服务...[0m"
"!NSSM_EXE!" start "%SERVICE_NAME%" >nul 2>&1

:: 检查服务是否启动成功
timeout /t 2 /nobreak >nul
sc query "%SERVICE_NAME%" | findstr /i "RUNNING" >nul 2>&1
if errorlevel 1 (
    call :color_print "[91m❌ 部署失败！服务未正常运行。[0m"
    call :color_print "[93mℹ️ 排查建议：[0m"
    call :color_print "   1. 手动运行：%cd%\%PROG_NAME% %ARGS%"
    call :color_print "   2. 查看日志：type %LOG_FILE%"
    call :color_print "   3. 查看服务状态：sc query %SERVICE_NAME%"
    pause
    exit /b 1
)

:: 输出成功信息
call :color_print "[92m🎉 部署成功！%SERVICE_NAME% 服务已配置完成。[0m"
echo.
call :color_print "[93m📌 常用管理命令：[0m"
call :color_print "   启动服务：net start %SERVICE_NAME%"
call :color_print "   停止服务：net stop %SERVICE_NAME%"
call :color_print "   重启服务：!NSSM_EXE! restart %SERVICE_NAME%"
call :color_print "   查看状态：sc query %SERVICE_NAME%"
call :color_print "   查看日志：type %LOG_FILE%"
call :color_print "   卸载服务：!NSSM_EXE! remove %SERVICE_NAME% confirm"
echo.
call :color_print "[92m✅ 操作完成！按任意键退出...[0m"
pause >nul
exit /b 0