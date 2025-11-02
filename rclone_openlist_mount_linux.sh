#!/bin/bash

# Rclone OpenList WebDAV 一键安装配置脚本
# 支持 Debian/Ubuntu、CentOS/RHEL、Fedora、Arch Linux、飞牛OS/OpenWrt
# 功能：自动安装rclone、配置WebDAV、挂载服务、设置自动启动

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件路径
LOG_FILE="$(pwd)/rclone_openlist_setup.log"

# 清除旧日志并创建新日志
> "$LOG_FILE"

# 日志函数
info_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp] 信息: $message${NC}" | tee -a "$LOG_FILE"
}

# 错误日志函数
error_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] 错误: $message${NC}" | tee -a "$LOG_FILE"
}

# 成功日志函数
success_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] 成功: $message${NC}" | tee -a "$LOG_FILE"
}

# 警告日志函数
warning_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] 警告: $message${NC}" | tee -a "$LOG_FILE"
}

# 检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
    return $?
}

# 检测系统类型
detect_os() {
    info_log "检测系统类型..."
    
    if [ -f /etc/debian_version ]; then
        OS="Debian"
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/centos-release ]; then
        OS="CentOS"
        VER=$(cat /etc/centos-release | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    elif [ -f /etc/fedora-release ]; then
        OS="Fedora"
        VER=$(cat /etc/fedora-release | grep -o '[0-9]\+' | head -1)
    elif [ -f /etc/arch-release ]; then
        OS="Arch"
        VER="滚动更新"
    elif [ -f /etc/openwrt_release ]; then
        OS="OpenWrt"
        VER=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d'=' -f2 | tr -d '"')
    elif grep -q "Phicomm N1" /etc/os-release 2>/dev/null || grep -q "flippy" /etc/os-release 2>/dev/null; then
        OS="飞牛OS"
        VER="未知"
    else
        OS="Unknown"
        VER="Unknown"
    fi
    
    info_log "系统检测结果: $OS $VER"
    return 0
}

# 安装系统依赖
install_dependencies() {
    info_log "安装必要依赖..."
    
    case "$OS" in
        "Debian")
            # Ubuntu/Debian - 增强的错误处理
            info_log "正在更新软件包列表..."
            apt-get update -y || {
                warning_log "初次更新失败，尝试修复apt源..."
                # 尝试修复常见的apt问题
                apt-get clean || true
                rm -rf /var/lib/apt/lists/* || true
                apt-get update -y || {
                    error_log "更新软件包列表失败，请检查网络连接或源配置"
                    return 1
                }
            }
            
            info_log "正在安装依赖包..."
            # 分别安装软件包，增加成功率
            apt-get install -y wget || {
                error_log "wget安装失败"
                return 1
            }
            apt-get install -y unzip || {
                error_log "unzip安装失败"
                return 1
            }
            apt-get install -y curl || {
                error_log "curl安装失败"
                return 1
            }
            apt-get install -y grep sed awk || {
                error_log "基础工具安装失败"
                return 1
            }
            # 尝试安装fuse3，如果失败则尝试fuse
            apt-get install -y fuse3 || {
                warning_log "fuse3安装失败，尝试安装fuse..."
                apt-get install -y fuse || {
                    warning_log "fuse也安装失败，将在后续操作中处理"
                }
            }
            ;;
        "CentOS")
            # CentOS/RHEL
            yum install -y wget unzip curl fuse grep sed awk || {
                error_log "CentOS依赖安装失败，尝试清理缓存后重试..."
                yum clean all
                yum makecache
                yum install -y wget unzip curl fuse grep sed awk >> "$LOG_FILE" 2>&1
            }
            ;;
        "Fedora")
            # Fedora
            dnf install -y wget unzip curl fuse3 grep sed awk || {
                error_log "Fedora依赖安装失败，尝试清理缓存后重试..."
                dnf clean all
                dnf makecache
                dnf install -y wget unzip curl fuse3 grep sed awk >> "$LOG_FILE" 2>&1
            }
            ;;
        "Arch")
            # Arch Linux
            pacman -Sy --noconfirm wget unzip curl fuse3 grep sed awk >> "$LOG_FILE" 2>&1
            ;;
        "OpenWrt")
            # OpenWrt
            opkg update >> "$LOG_FILE" 2>&1
            opkg install wget unzip curl grep sed awk >> "$LOG_FILE" 2>&1
            ;;
        "飞牛OS")
            # 飞牛OS (类似Debian)
            apt-get update -y || {
                warning_log "初次更新失败，尝试修复apt源..."
                apt-get clean || true
                rm -rf /var/lib/apt/lists/* || true
                apt-get update -y || {
                    error_log "更新软件包列表失败"
                    return 1
                }
            }
            apt-get install -y wget unzip curl fuse grep sed awk >> "$LOG_FILE" 2>&1
            ;;
        *)
            error_log "不支持的系统类型"
            return 1
            ;;
    esac
    
    # 即使有部分包安装失败，也检查关键工具是否存在
    check_command wget || {
        error_log "关键工具wget缺失"
        return 1
    }
    check_command unzip || {
        error_log "关键工具unzip缺失"
        return 1
    }
    check_command curl || {
        error_log "关键工具curl缺失"
        return 1
    }
    
    success_log "关键依赖安装成功"
    return 0
}

# 安装rclone
install_rclone() {
    info_log "安装rclone..."
    
    # 检查rclone是否已安装
    if check_command rclone; then
        info_log "rclone已安装，版本: $(rclone version | grep 'rclone' | head -1)"
        return 0
    fi
    
    # 根据系统架构下载对应版本
    ARCH=$(uname -m)
    case "$ARCH" in
        "x86_64")
            RCLONE_ARCH="amd64"
            ;;
        "aarch64" | "armv8l")
            RCLONE_ARCH="arm64"
            ;;
        "armv7l")
            RCLONE_ARCH="arm-v7"
            ;;
        "i686")
            RCLONE_ARCH="386"
            ;;
        *)
            error_log "不支持的系统架构: $ARCH"
            return 1
            ;;
    esac
    
    # 下载并安装rclone
    RCLONE_TEMP_DIR=$(mktemp -d)
    cd "$RCLONE_TEMP_DIR" || return 1
    
    info_log "下载rclone for $RCLONE_ARCH..."
    wget -q https://downloads.rclone.org/rclone-current-linux-${RCLONE_ARCH}.zip -O rclone.zip >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        error_log "rclone下载失败"
        cd - >/dev/null || return 1
        rm -rf "$RCLONE_TEMP_DIR"
        return 1
    fi
    
    unzip rclone.zip >> "$LOG_FILE" 2>&1
    cd rclone-*-linux-${RCLONE_ARCH} || return 1
    
    info_log "安装rclone..."
    # 检测是否为root用户
    if [ $(id -u) -eq 0 ]; then
        install -m 755 rclone /usr/bin/ || return 1
        install -m 644 rclone.1 /usr/share/man/man1/ || true
        mandb || true
    else
        # 非root用户安装到用户目录
        mkdir -p ~/.local/bin
        cp rclone ~/.local/bin/
        chmod +x ~/.local/bin/rclone
        # 添加到PATH
        if ! grep -q "~/.local/bin" ~/.bashrc; then
            echo 'export PATH="$PATH:~/.local/bin"' >> ~/.bashrc
            source ~/.bashrc
        fi
    fi
    
    cd - >/dev/null || return 1
    rm -rf "$RCLONE_TEMP_DIR"
    
    if check_command rclone; then
        success_log "rclone安装成功，版本: $(rclone version | grep 'rclone' | head -1)"
        return 0
    else
        error_log "rclone安装失败"
        return 1
    fi
}

# 配置rclone WebDAV
configure_rclone() {
    info_log "配置rclone WebDAV..."
    
    # 创建rclone配置目录
    mkdir -p ~/.config/rclone
    
    # 备份原有配置
    if [ -f ~/.config/rclone/rclone.conf ]; then
        cp ~/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf.$(date +%Y%m%d%H%M%S).bak
        info_log "已备份原有配置文件"
    fi
    
    # 再次确保URL不以斜杠结尾（双重保障）
    CLEAN_WEBDAV_URL=$(echo "$WEBDAV_URL" | sed 's/\/$//')
    
    # 创建配置文件
    cat > ~/.config/rclone/rclone.conf << EOF
[webdav]
type = webdav
url = $CLEAN_WEBDAV_URL
vendor = other
user = $WEBDAV_USER
pass = $WEBDAV_PASS_ENCRYPTED
EOF
    
    if [ $? -eq 0 ]; then
        success_log "rclone配置成功"
        return 0
    else
        error_log "rclone配置失败"
        return 1
    fi
}

# 创建挂载点
create_mount_point() {
    info_log "创建挂载点: $MOUNT_POINT..."
    
    # 检查挂载点是否存在
    if [ ! -d "$MOUNT_POINT" ]; then
        mkdir -p "$MOUNT_POINT" >> "$LOG_FILE" 2>&1 || {
            error_log "创建挂载点目录失败"
            return 1
        }
        
        # 设置挂载点权限
        if [ "$OS" != "OpenWrt" ] && [ "$OS" != "飞牛OS" ]; then
            chmod 755 "$MOUNT_POINT" >> "$LOG_FILE" 2>&1 || {
                warning_log "设置挂载点权限失败"
            }
        fi
    fi
    
    success_log "挂载点准备就绪"
    return 0
}

# 挂载WebDAV服务
mount_webdav() {
    info_log "挂载WebDAV服务到 $MOUNT_POINT..."
    
    # 检查是否已挂载
    if mount | grep -q "$MOUNT_POINT"; then
        info_log "检测到$MOUNT_POINT已挂载，先卸载..."
        umount "$MOUNT_POINT" >> "$LOG_FILE" 2>&1
    fi
    
    # 执行挂载命令
    rclone mount webdav: "$MOUNT_POINT" \
        --umask 0000 \
        --default-permissions \
        --allow-non-empty \
        --allow-other \
        --dir-cache-time 6h \
        --buffer-size 64M \
        --low-level-retries 200 \
        --vfs-read-chunk-size $CHUNK_SIZE \
        --vfs-read-chunk-size-limit 2G \
        --daemon >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        # 等待挂载完成
        sleep 3
        if mount | grep -q "$MOUNT_POINT"; then
            success_log "WebDAV服务挂载成功!"
            return 0
        else
            error_log "挂载失败，挂载点未出现在挂载列表中"
            return 1
        fi
    else
        error_log "挂载命令执行失败"
        return 1
    fi
}

# 设置自动启动
setup_autostart() {
    info_log "设置自动启动..."
    
    # 创建启动脚本
    AUTOSTART_SCRIPT="/etc/init.d/rclone_openlist"

    if [ "$OS" = "OpenWrt" ] || [ "$OS" = "飞牛OS" ]; then
        # OpenWrt/飞牛OS使用procd
        cat > "$AUTOSTART_SCRIPT" << EOF
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    sleep 30
    $(command -v rclone) mount webdav: "$MOUNT_POINT" \
        --umask 0000 \
        --default-permissions \
        --allow-non-empty \
        --allow-other \
        --dir-cache-time 6h \
        --buffer-size 64M \
        --low-level-retries 200 \
        --vfs-read-chunk-size $CHUNK_SIZE \
        --vfs-read-chunk-size-limit 2G \
        --daemon
}

stop() {
    killall -9 rclone
    umount "$MOUNT_POINT" 2>/dev/null
}
EOF
        
        # 替换脚本中的变量
        sed -i "s|\$MOUNT_POINT|$MOUNT_POINT|g" "$AUTOSTART_SCRIPT"
        sed -i "s|\$CHUNK_SIZE|$CHUNK_SIZE|g" "$AUTOSTART_SCRIPT"
        
        # 设置权限并启用
        chmod +x "$AUTOSTART_SCRIPT"
        /etc/init.d/rclone_openlist enable
    else
        # 其他系统使用systemd或init.d
        if check_command systemctl; then
            # 使用systemd
            SYSTEMD_SERVICE="/etc/systemd/system/rclone-openlist.service"
            
            cat > "$SYSTEMD_SERVICE" << EOF
[Unit]
Description=Rclone WebDAV Mount
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStartPre=/bin/sleep 30
ExecStart=$(command -v rclone) mount webdav: "$MOUNT_POINT" \
    --umask 0000 \
    --default-permissions \
    --allow-non-empty \
    --allow-other \
    --dir-cache-time 6h \
    --buffer-size 64M \
    --low-level-retries 200 \
    --vfs-read-chunk-size $CHUNK_SIZE \
    --vfs-read-chunk-size-limit 2G
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
            
            # 启用并启动服务
            systemctl daemon-reload
            systemctl enable rclone-openlist.service
        else
            # 使用init.d
            cat > "$AUTOSTART_SCRIPT" << EOF
#!/bin/bash

case "\$1" in
    start)
        sleep 30
        $(command -v rclone) mount webdav: "$MOUNT_POINT" \
            --umask 0000 \
            --default-permissions \
            --allow-non-empty \
            --allow-other \
            --dir-cache-time 6h \
            --buffer-size 64M \
            --low-level-retries 200 \
            --vfs-read-chunk-size $CHUNK_SIZE \
            --vfs-read-chunk-size-limit 2G \
            --daemon
        ;;
    stop)
        killall -9 rclone 2>/dev/null
        umount "$MOUNT_POINT" 2>/dev/null
        ;;
    restart)
        \$0 stop
        sleep 2
        \$0 start
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac
EOF
            
            # 设置权限并添加到启动项
            chmod +x "$AUTOSTART_SCRIPT"
            
            if [ -d "/etc/init.d" ]; then
                # Debian/Ubuntu/CentOS
                update-rc.d rclone_openlist defaults 99 10 2>/dev/null || \
                chkconfig --add rclone_openlist 2>/dev/null
            fi
        fi
    fi
    
    # 额外的crontab保障机制
    CRONTAB_ENTRY="@reboot sleep 60 && $(command -v rclone) mount webdav: \"$MOUNT_POINT\" --umask 0000 --default-permissions --allow-non-empty --allow-other --dir-cache-time 6h --buffer-size 64M --low-level-retries 200 --vfs-read-chunk-size $CHUNK_SIZE --vfs-read-chunk-size-limit 2G --daemon"
    
    # 检查crontab是否已存在该条目
    if ! crontab -l 2>/dev/null | grep -q "rclone mount openlist"; then
        (crontab -l 2>/dev/null; echo "$CRONTAB_ENTRY") | crontab -
    fi
    
    success_log "自动启动设置完成"
    return 0
}

# 显示挂载信息
show_mount_info() {
    clear
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}        Rclone OpenList 配置完成          ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo -e "${BLUE}WebDAV 地址:${NC} $WEBDAV_URL"
    echo -e "${BLUE}WebDAV 账号:${NC} $WEBDAV_USER"
    echo -e "${BLUE}挂载点:${NC} $MOUNT_POINT"
    echo -e "${BLUE}分片大小:${NC} $CHUNK_SIZE"
    echo -e "${BLUE}自动启动:${NC} 已设置 (开机延迟30秒)"
    echo -e "${GREEN}============================================${NC}"
    echo -e "${YELLOW}挂载状态:${NC}"
    
    if mount | grep -q "$MOUNT_POINT"; then
        echo -e "  ${GREEN}✓ 已成功挂载${NC}"
        echo -e "  ${BLUE}挂载目录内容:${NC}"
        ls -la "$MOUNT_POINT" 2>/dev/null || echo "  (目录可能为空)"
    else
        echo -e "  ${RED}✗ 挂载失败${NC}"
        echo -e "  ${YELLOW}请检查日志文件: $LOG_FILE${NC}"
    fi
    
    echo -e "${GREEN}============================================${NC}"
    echo -e "${YELLOW}提示:${NC}"
    echo -e "  1. 如需手动挂载: rclone mount openlist: '$MOUNT_POINT' --daemon"
    echo -e "  2. 如需卸载: umount '$MOUNT_POINT'"
    echo -e "  3. 查看rclone版本: rclone version"
    echo -e "  4. 详细日志已保存至: $LOG_FILE"
    echo -e "${GREEN}============================================${NC}"
}

# 主函数
main() {
    clear
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}    Rclone OpenList WebDAV 一键配置脚本    ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo -e "${BLUE}支持系统:${NC} Debian/Ubuntu、CentOS/RHEL、Fedora、Arch Linux、OpenWrt、飞牛OS"
    echo -e "${BLUE}功能:${NC} 自动安装rclone、配置WebDAV、挂载服务、设置自动启动"
    echo -e "${GREEN}============================================${NC}"
    echo -e ""
    
    # 检测系统
    detect_os
    
    # 提示用户输入配置信息
    echo -e "${YELLOW}请输入WebDAV配置信息:${NC}"
    read -p "WebDAV地址 (例如: https://example.com/dav): " WEBDAV_URL
    # 确保URL不以斜杠结尾
    WEBDAV_URL=$(echo "$WEBDAV_URL" | sed 's/\/$//')
    read -p "WebDAV用户名: " WEBDAV_USER
    read -s -p "WebDAV密码: " WEBDAV_PASS
    echo -e ""
    read -p "挂载点路径 (默认: /mnt/openlist): " MOUNT_POINT
    MOUNT_POINT=${MOUNT_POINT:-/mnt/openlist}
    read -p "分片大小 (默认: 64M，可选: 32M/64M/128M/256M): " CHUNK_SIZE
    CHUNK_SIZE=${CHUNK_SIZE:-64M}
    
    echo -e ""
    echo -e "${YELLOW}开始安装配置...${NC}"
    echo -e ""
    
    # 安装依赖
    if ! install_dependencies; then
        error_log "依赖安装失败，请检查权限"
        exit 1
    fi
    
    # 安装rclone
    if ! install_rclone; then
        error_log "rclone安装失败"
        exit 1
    fi
    
    # 加密密码 - 确保在rclone安装后执行
    if command -v rclone > /dev/null 2>&1; then
        WEBDAV_PASS_ENCRYPTED=$(rclone obscure "$WEBDAV_PASS" 2>/dev/null || echo "$WEBDAV_PASS")
    else
        WEBDAV_PASS_ENCRYPTED="$WEBDAV_PASS"
        warning_log "无法使用rclone obscure加密密码，将使用明文密码"
    fi
    
    # 配置rclone
    if ! configure_rclone; then
        error_log "rclone配置失败"
        exit 1
    fi
    
    # 创建挂载点
    if ! create_mount_point; then
        error_log "挂载点创建失败，请检查权限"
        exit 1
    fi
    
    # 挂载WebDAV
    if ! mount_webdav; then
        error_log "WebDAV挂载失败"
        # 继续执行，因为可能是权限问题，但自动启动仍需设置
    fi
    
    # 设置自动启动
    if ! setup_autostart; then
        error_log "自动启动设置失败"
    fi
    
    # 显示结果
    show_mount_info
    
    info_log "脚本执行完成"
}

# 菜单函数
show_menu() {
    # 先检测系统
    detect_os
    
    # 检查权限
    if [ $(id -u) -ne 0 ] && [ "$OS" != "OpenWrt" ]; then
        echo -e "${YELLOW}警告: 建议使用root用户运行以获得最佳体验${NC}"
        read -p "是否继续? (y/n): " continue
        if [ "$continue" != "y" ]; then
            exit 0
        fi
    fi
    
    while true; do
        clear
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}      Rclone OpenList WebDAV 管理菜单      ${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo -e "${BLUE}1.${NC} 全新安装配置"
        echo -e "${BLUE}2.${NC} 重新挂载WebDAV"
        echo -e "${BLUE}3.${NC} 卸载WebDAV"
        echo -e "${BLUE}4.${NC} 查看挂载状态"
        echo -e "${BLUE}5.${NC} 查看日志"
        echo -e "${BLUE}6.${NC} 退出"
        echo -e "${GREEN}============================================${NC}"
        read -p "请选择操作 [1-6]: " choice
        
        case $choice in
            1)
                main
                read -p "按Enter键返回菜单..."
                ;;
            2)
                echo -e "重新挂载WebDAV..."
                # 读取配置信息
                if [ -f ~/.config/rclone/rclone.conf ]; then
                    WEBDAV_URL=$(grep -A 4 "\[webdav\]" ~/.config/rclone/rclone.conf | grep "url =" | cut -d'=' -f2 | tr -d ' ')
                    WEBDAV_USER=$(grep -A 4 "\[webdav\]" ~/.config/rclone/rclone.conf | grep "user =" | cut -d'=' -f2 | tr -d ' ')
                    WEBDAV_PASS_ENCRYPTED=$(grep -A 4 "\[webdav\]" ~/.config/rclone/rclone.conf | grep "pass =" | cut -d'=' -f2 | tr -d ' ')
                    MOUNT_POINT=$(mount | grep "rclone" | awk '{print $3}' || echo "/mnt/openlist")
                    CHUNK_SIZE="64M" # 默认值
                    
                    # 卸载并重新挂载
                    umount "$MOUNT_POINT" 2>/dev/null
                    mount_webdav
                    read -p "按Enter键返回菜单..."
                else
                    echo -e "${RED}未找到配置文件，请先运行全新安装配置${NC}"
                    read -p "按Enter键返回菜单..."
                fi
                ;;
            3)
                echo -e "卸载WebDAV..."
                MOUNT_POINT=$(mount | grep "rclone" | awk '{print $3}' || echo "/mnt/openlist")
                if umount "$MOUNT_POINT" 2>/dev/null; then
                    echo -e "${GREEN}卸载成功${NC}"
                else
                    echo -e "${RED}卸载失败，可能未挂载或权限不足${NC}"
                fi
                read -p "按Enter键返回菜单..."
                ;;
            4)
                echo -e "挂载状态:"
                if mount | grep -q "rclone"; then
                    mount | grep "rclone"
                else
                    echo -e "${RED}未检测到rclone挂载${NC}"
                fi
                read -p "按Enter键返回菜单..."
                ;;
            5)
                echo -e "查看最近的日志..."
                tail -n 50 "$LOG_FILE"
                read -p "按Enter键返回菜单..."
                ;;
            6)
                echo -e "${GREEN}谢谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入${NC}"
                read -p "按Enter键继续..."
                ;;
        esac
    done
}

# 启动菜单
show_menu

# 检查权限 - 移到show_menu函数内部调用，因为需要先定义OS变量
