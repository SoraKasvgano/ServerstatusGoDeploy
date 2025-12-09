#!/bin/bash
set -e  # 遇到错误立即退出

# ===================== 核心配置（无需修改） =====================
PROG_NAME="serverstatus"
SERVICE_NAME="serverstatus"
PID_FILE="/var/run/${SERVICE_NAME}.pid"
LOG_FILE="/var/log/${SERVICE_NAME}.log"

# ===================== 强制设置UTF-8编码（解决中文方框核心） =====================
# 临时设置locale为UTF-8（立即生效）
export LC_ALL=en_US.UTF-8  # 优先用en_US.UTF-8（兼容无中文locale的系统）
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_MESSAGES=en_US.UTF-8

# 永久写入系统配置（适配不同系统）
set_permanent_utf8() {
    # OpenWRT：写入/etc/profile
    if [ -f "/etc/openwrt_release" ]; then
        grep -q "LC_ALL=en_US.UTF-8" /etc/profile || echo "export LC_ALL=en_US.UTF-8" >> /etc/profile
        grep -q "LANG=en_US.UTF-8" /etc/profile || echo "export LANG=en_US.UTF-8" >> /etc/profile
        grep -q "LC_CTYPE=en_US.UTF-8" /etc/profile || echo "export LC_CTYPE=en_US.UTF-8" >> /etc/profile
        source /etc/profile
    # Linux Systemd（CentOS7+/Ubuntu16+）：写入/etc/locale.conf
    elif [ -f "/etc/systemd/system.conf" ]; then
        grep -q "LANG=en_US.UTF-8" /etc/locale.conf || echo "LANG=en_US.UTF-8" >> /etc/locale.conf
        grep -q "LC_ALL=en_US.UTF-8" /etc/locale.conf || echo "LC_ALL=en_US.UTF-8" >> /etc/locale.conf
        localectl set-locale LANG=en_US.UTF-8 2>/dev/null || true
    # Linux SysV（CentOS6/老Debian）：写入/etc/sysconfig/i18n或/etc/default/locale
    else
        if [ -f "/etc/sysconfig/i18n" ]; then
            grep -q "LANG=en_US.UTF-8" /etc/sysconfig/i18n || echo "LANG=en_US.UTF-8" >> /etc/sysconfig/i18n
            grep -q "LC_ALL=en_US.UTF-8" /etc/sysconfig/i18n || echo "LC_ALL=en_US.UTF-8" >> /etc/sysconfig/i18n
        elif [ -f "/etc/default/locale" ]; then
            grep -q "LANG=en_US.UTF-8" /etc/default/locale || echo "LANG=en_US.UTF-8" >> /etc/default/locale
            grep -q "LC_ALL=en_US.UTF-8" /etc/default/locale || echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
        fi
    fi
}

# ===================== 颜色输出（兼容UTF-8，避免乱码） =====================
# 改用英文+颜色（若仍需中文，脚本会先检测字体）
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

# ===================== 检测中文字体（提示安装，可选） =====================
check_chinese_font() {
    if [ -f "/etc/openwrt_release" ]; then
        # OpenWRT检测字体
        if ! opkg list-installed | grep -q "fonts-wqy-microhei"; then
            yellow "Warning: No Chinese font installed (may display square boxes for Chinese)"
            yellow "Install Chinese font (need network): opkg update && opkg install fonts-wqy-microhei"
        fi
    else
        # Linux检测字体
        if ! fc-list | grep -q "wqy" && ! fc-list | grep -q "Chinese"; then
            yellow "Warning: No Chinese font installed (may display square boxes for Chinese)"
            if [ -f "/etc/debian_version" ]; then
                yellow "Install Chinese font: apt update && apt install -y fonts-wqy-microhei"
            elif [ -f "/etc/redhat-release" ]; then
                yellow "Install Chinese font: yum install -y wqy-microhei-fonts"
            fi
        fi
    fi
}

# ===================== 主逻辑：初始化 + 部署 =====================
main() {
    blue "===== Step 1: Set UTF-8 encoding (fix Chinese square boxes) ====="
    set_permanent_utf8
    green "? UTF-8 encoding configured successfully"

    blue "\n===== Step 2: Check system environment ====="
    # 检测中文字体（提示）
    check_chinese_font

    # 获取脚本目录
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    PROG_PATH="${SCRIPT_DIR}/${PROG_NAME}"
    if [ ! -f "${PROG_PATH}" ]; then
        red "Error: ${PROG_NAME} not found in ${SCRIPT_DIR}!"
        exit 1
    fi
    chmod +x "${PROG_PATH}"
    green "? ${PROG_PATH} is executable"

    # 识别系统类型
    if [ -f "/etc/openwrt_release" ]; then
        SYS_TYPE="openwrt"
        SERVICE_DIR="/etc/init.d"
        ENABLE_CMD="${SERVICE_DIR}/${SERVICE_NAME} enable"
        DISABLE_CMD="${SERVICE_DIR}/${SERVICE_NAME} disable"
    elif [ -f "/etc/systemd/system.conf" ]; then
        SYS_TYPE="linux_systemd"
        SERVICE_DIR="/etc/systemd/system"
        SERVICE_FILE="${SERVICE_DIR}/${SERVICE_NAME}.service"
        ENABLE_CMD="systemctl enable ${SERVICE_NAME}"
        DISABLE_CMD="systemctl disable ${SERVICE_NAME}"
    elif [ -f "/etc/init.d/functions" ]; then
        SYS_TYPE="linux_sysv"
        SERVICE_DIR="/etc/init.d"
        ENABLE_CMD="chkconfig --add ${SERVICE_NAME} && chkconfig ${SERVICE_NAME} on"
        DISABLE_CMD="chkconfig ${SERVICE_NAME} off"
    else
        red "Error: Unsupported system (only OpenWRT/Linux supported)"
        exit 1
    fi
    green "? System type detected: ${SYS_TYPE}"

    blue "\n===== Step 3: Input running parameters ====="
    yellow "Please enter the full parameter after -dsn (example: user:pass@server-ip:35601):"
    read -r DSN_PARAM
    if [ -z "${DSN_PARAM}" ]; then
        red "Error: Parameter cannot be empty!"
        exit 1
    fi
    ARGS="-dsn ${DSN_PARAM}"
    green "? Running parameters obtained: ${ARGS}"

    blue "\n===== Step 4: Generate service configuration ====="
    # 生成服务配置（同之前逻辑，略作UTF-8适配）
    if [ "${SYS_TYPE}" = "openwrt" ]; then
        cat > "${SERVICE_DIR}/${SERVICE_NAME}" << EOF
#!/bin/sh /etc/rc.common
START=90
STOP=10
PROG="${PROG_PATH}"
ARGS="${ARGS}"
PID_FILE="${PID_FILE}"
LOG_FILE="${LOG_FILE}"

# Force UTF-8 for service
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

start() {
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "${SERVICE_NAME} is already running"
        return 0
    fi
    echo "Starting ${SERVICE_NAME}..."
    until ping -c 1 \$(echo "\$ARGS" | grep -oE '@[0-9.]+' | cut -c2-) >/dev/null 2>&1; do
        echo "Waiting for target server to be reachable..."
        sleep 1
    done
    \$PROG \$ARGS >\$LOG_FILE 2>&1 &
    echo \$! > "\$PID_FILE"
    echo "${SERVICE_NAME} started successfully, PID: \$(cat \$PID_FILE)"
}

stop() {
    if [ ! -f "\$PID_FILE" ] || ! kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "${SERVICE_NAME} is not running"
        return 0
    fi
    echo "Stopping ${SERVICE_NAME}..."
    kill \$(cat "\$PID_FILE") 2>/dev/null
    rm -f "\$PID_FILE"
    echo "${SERVICE_NAME} stopped successfully"
}

restart() {
    stop
    sleep 1
    start
}
EOF
        chmod +x "${SERVICE_DIR}/${SERVICE_NAME}"
        green "? OpenWRT service script generated: ${SERVICE_DIR}/${SERVICE_NAME}"

    elif [ "${SYS_TYPE}" = "linux_systemd" ]; then
        cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=ServerStatus Service
After=network.target
Wants=network.target

[Service]
Type=simple
Environment="LC_ALL=en_US.UTF-8" "LANG=en_US.UTF-8"
ExecStart=${PROG_PATH} ${ARGS}
ExecStop=/bin/kill -TERM \$MAINPID
PIDFile=${PID_FILE}
Restart=on-failure
RestartSec=3
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}
WorkingDirectory=${SCRIPT_DIR}

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        green "? Systemd service config generated: ${SERVICE_FILE}"

    elif [ "${SYS_TYPE}" = "linux_sysv" ]; then
        cat > "${SERVICE_DIR}/${SERVICE_NAME}" << EOF
#!/bin/bash
# chkconfig: 2345 90 10
# description: ServerStatus Service

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
PROG="${PROG_PATH}"
ARGS="${ARGS}"
PID_FILE="${PID_FILE}"
LOG_FILE="${LOG_FILE}"

start() {
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "${SERVICE_NAME} is already running"
        return 0
    fi
    echo "Starting ${SERVICE_NAME}..."
    until ping -c 1 \$(echo "\$ARGS" | grep -oE '@[0-9.]+' | cut -c2-) >/dev/null 2>&1; do
        echo "Waiting for target server to be reachable..."
        sleep 1
    done
    \$PROG \$ARGS >\$LOG_FILE 2>&1 &
    echo \$! > "\$PID_FILE"
    echo "${SERVICE_NAME} started successfully, PID: \$(cat \$PID_FILE)"
}

stop() {
    if [ ! -f "\$PID_FILE" ] || ! kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "${SERVICE_NAME} is not running"
        return 0
    fi
    echo "Stopping ${SERVICE_NAME}..."
    kill \$(cat "\$PID_FILE") 2>/dev/null
    rm -f "\$PID_FILE"
    echo "${SERVICE_NAME} stopped successfully"
}

restart() {
    stop
    sleep 1
    start
}

case "\$1" in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    *) echo "Usage: \$0 {start|stop|restart}" ;;
esac
EOF
        chmod +x "${SERVICE_DIR}/${SERVICE_NAME}"
        green "? SysV service script generated: ${SERVICE_DIR}/${SERVICE_NAME}"
    fi

    blue "\n===== Step 5: Enable auto-start and start service ====="
    eval "${ENABLE_CMD}"
    green "? ${SERVICE_NAME} set to auto-start on boot"

    # 启动服务
    if [ "${SYS_TYPE}" = "openwrt" ]; then
        "${SERVICE_DIR}/${SERVICE_NAME}" start
    elif [ "${SYS_TYPE}" = "linux_systemd" ]; then
        systemctl start "${SERVICE_NAME}"
        systemctl status "${SERVICE_NAME}" --no-pager || true
    elif [ "${SYS_TYPE}" = "linux_sysv" ]; then
        "${SERVICE_DIR}/${SERVICE_NAME}" start
    fi

    blue "\n===== Step 6: Verify deployment ====="
    sleep 2
    if ps aux | grep -v grep | grep "${PROG_PATH}" >/dev/null; then
        green "?? Deployment successful! ${PROG_NAME} is running and set to auto-start."
        yellow "?? Common commands:"
        if [ "${SYS_TYPE}" = "openwrt" ]; then
            echo "  Start: /etc/init.d/${SERVICE_NAME} start"
            echo "  Stop: /etc/init.d/${SERVICE_NAME} stop"
            echo "  Restart: /etc/init.d/${SERVICE_NAME} restart"
            echo "  Log: cat ${LOG_FILE}"
        elif [ "${SYS_TYPE}" = "linux_systemd" ]; then
            echo "  Start: systemctl start ${SERVICE_NAME}"
            echo "  Stop: systemctl stop ${SERVICE_NAME}"
            echo "  Restart: systemctl restart ${SERVICE_NAME}"
            echo "  Status: systemctl status ${SERVICE_NAME}"
            echo "  Log: cat ${LOG_FILE}"
        elif [ "${SYS_TYPE}" = "linux_sysv" ]; then
            echo "  Start: /etc/init.d/${SERVICE_NAME} start"
            echo "  Stop: /etc/init.d/${SERVICE_NAME} stop"
            echo "  Restart: /etc/init.d/${SERVICE_NAME} restart"
            echo "  Log: cat ${LOG_FILE}"
        fi
    else
        red "? Deployment failed! Check log: ${LOG_FILE}"
        exit 1
    fi
}

# 执行主逻辑
main