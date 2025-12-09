#!/bin/bash
set -e  # 遇到错误立即退出

# ===================== 核心配置（与部署脚本保持一致） =====================
SERVICE_NAME="serverstatus"
PROG_NAME="serverstatus"
PID_FILE="/var/run/${SERVICE_NAME}.pid"
LOG_FILE="/var/log/${SERVICE_NAME}.log"

# ===================== 颜色输出函数 =====================
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

# ===================== 第一步：识别系统类型 =====================
blue "===== Step 1: Detect system type ====="
if [ -f "/etc/openwrt_release" ]; then
    SYS_TYPE="openwrt"
    SERVICE_SCRIPT="/etc/init.d/${SERVICE_NAME}"
elif [ -f "/etc/systemd/system.conf" ]; then
    SYS_TYPE="linux_systemd"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
elif [ -f "/etc/init.d/functions" ]; then
    SYS_TYPE="linux_sysv"
    SERVICE_SCRIPT="/etc/init.d/${SERVICE_NAME}"
else
    red "Error: Unsupported system (only OpenWRT/Linux supported)"
    exit 1
fi
green "✅ Detected system type: ${SYS_TYPE}"

# ===================== 第二步：停止服务/进程 =====================
blue "\n===== Step 2: Stop service/process ====="
# 停止服务
if [ "${SYS_TYPE}" = "openwrt" ]; then
    if [ -f "${SERVICE_SCRIPT}" ]; then
        yellow "ℹ️ Stopping ${SERVICE_NAME} service..."
        ${SERVICE_SCRIPT} stop || true
    fi
elif [ "${SYS_TYPE}" = "linux_systemd" ]; then
    yellow "ℹ️ Stopping ${SERVICE_NAME} service..."
    systemctl stop ${SERVICE_NAME} || true
elif [ "${SYS_TYPE}" = "linux_sysv" ]; then
    if [ -f "${SERVICE_SCRIPT}" ]; then
        yellow "ℹ️ Stopping ${SERVICE_NAME} service..."
        ${SERVICE_SCRIPT} stop || true
    fi
fi

# 强制杀死残留进程（兜底）
if ps aux | grep -v grep | grep "${PROG_NAME}" >/dev/null; then
    yellow "ℹ️ Killing remaining ${PROG_NAME} processes..."
    pkill -f "${PROG_NAME}" || true
    # 兼容pkill不可用的场景
    kill -9 $(ps aux | grep -v grep | grep "${PROG_NAME}" | awk '{print $2}') 2>/dev/null || true
fi

# 删除PID文件
if [ -f "${PID_FILE}" ]; then
    yellow "ℹ️ Removing PID file: ${PID_FILE}"
    rm -f "${PID_FILE}"
fi
green "✅ Service/process stopped completely"

# ===================== 第三步：卸载服务配置 =====================
blue "\n===== Step 3: Uninstall service configuration ====="
if [ "${SYS_TYPE}" = "openwrt" ]; then
    # OpenWRT：禁用+删除服务脚本
    if [ -f "${SERVICE_SCRIPT}" ]; then
        yellow "ℹ️ Disabling ${SERVICE_NAME} auto-start..."
        ${SERVICE_SCRIPT} disable || true
        yellow "ℹ️ Removing service script: ${SERVICE_SCRIPT}"
        rm -f "${SERVICE_SCRIPT}"
        # 清理rc.d软链接
        rm -f /etc/rc.d/S*${SERVICE_NAME} || true
    else
        yellow "ℹ️ No OpenWRT service script found, skip"
    fi
elif [ "${SYS_TYPE}" = "linux_systemd" ]; then
    # Systemd：禁用+删除服务文件
    yellow "ℹ️ Disabling ${SERVICE_NAME} auto-start..."
    systemctl disable ${SERVICE_NAME} || true
    if [ -f "${SERVICE_FILE}" ]; then
        yellow "ℹ️ Removing service file: ${SERVICE_FILE}"
        rm -f "${SERVICE_FILE}"
        # 重新加载systemd配置
        systemctl daemon-reload
        systemctl reset-failed ${SERVICE_NAME} || true
    else
        yellow "ℹ️ No Systemd service file found, skip"
    fi
elif [ "${SYS_TYPE}" = "linux_sysv" ]; then
    # SysV：禁用+删除服务脚本
    yellow "ℹ️ Disabling ${SERVICE_NAME} auto-start..."
    chkconfig ${SERVICE_NAME} off || true
    chkconfig --del ${SERVICE_NAME} || true
    if [ -f "${SERVICE_SCRIPT}" ]; then
        yellow "ℹ️ Removing service script: ${SERVICE_SCRIPT}"
        rm -f "${SERVICE_SCRIPT}"
    else
        yellow "ℹ️ No SysV service script found, skip"
    fi
fi
green "✅ Service configuration uninstalled"

# ===================== 第四步：清理日志文件 =====================
blue "\n===== Step 4: Clean up log files ====="
if [ -f "${LOG_FILE}" ]; then
    yellow "ℹ️ Removing log file: ${LOG_FILE}"
    rm -f "${LOG_FILE}"
else
    yellow "ℹ️ No log file found, skip"
fi
green "✅ Log files cleaned up"

# ===================== 第五步：验证卸载结果 =====================
blue "\n===== Step 5: Verify uninstall result ====="
# 检查服务是否残留
if [ "${SYS_TYPE}" = "openwrt" ]; then
    if [ ! -f "${SERVICE_SCRIPT}" ] && ! ls /etc/rc.d/S*${SERVICE_NAME} 2>/dev/null; then
        green "🎉 Uninstall successful! ${SERVICE_NAME} service is completely removed."
    else
        red "❌ Uninstall incomplete! Please clean up manually."
    fi
elif [ "${SYS_TYPE}" = "linux_systemd" ]; then
    if systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
        red "❌ Uninstall incomplete! Service file still exists."
    else
        green "🎉 Uninstall successful! ${SERVICE_NAME} service is completely removed."
    fi
elif [ "${SYS_TYPE}" = "linux_sysv" ]; then
    if ! chkconfig --list | grep -q "${SERVICE_NAME}" && [ ! -f "${SERVICE_SCRIPT}" ]; then
        green "🎉 Uninstall successful! ${SERVICE_NAME} service is completely removed."
    else
        red "❌ Uninstall incomplete! Please clean up manually."
    fi
fi

# 检查进程是否残留
if ps aux | grep -v grep | grep "${PROG_NAME}" >/dev/null; then
    red "⚠️ Warning: ${PROG_NAME} process is still running! Kill manually with:"
    red "   pkill -f ${PROG_NAME} or kill -9 \$(ps aux | grep -v grep | grep ${PROG_NAME} | awk '{print \$2}')"
else
    green "✅ No remaining ${PROG_NAME} processes."
fi

echo -e "\n"
green "✅ Uninstall script executed completely!"
yellow "📌 If you need to delete the ${PROG_NAME} binary file, run: rm -f /path/to/${PROG_NAME}"