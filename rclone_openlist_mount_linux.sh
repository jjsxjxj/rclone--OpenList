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

# 安装单个依赖的通用函数（按需安装）
install_single_dependency() {
    local tool_name="$1"
    local package_name="$2"
    local fallback_package="$3"
    
    # 先检查命令是否已存在
    if check_command "$tool_name"; then
        info_log "$tool_name 已存在，跳过安装"
        return 0
    fi
    
    info_log "尝试安装 $package_name..."
    
    case "$OS" in
        "Debian"|"飞牛OS")
            apt-get install -y "$package_name" || {
                error_log "$package_name 安装失败"
                
                # 如果有备选包，尝试安装
                if [ -n "$fallback_package" ]; then
                    warning_log "尝试安装备选包 $fallback_package..."
                    apt-get install -y "$fallback_package" || {
                        error_log "$fallback_package 安装也失败"
                        return 1
                    }
                    
                    # 创建符号链接
                    if [ "$tool_name" != "$fallback_package" ]; then
                        ln -sf "$(which "$fallback_package")" "/usr/bin/$tool_name" 2>/dev/null || {
                            warning_log "无法创建 $tool_name 符号链接"
                        }
                    fi
                else
                    return 1
                fi
            }
            ;;
        "CentOS")
            yum install -y "$package_name" || {
                error_log "$package_name 安装失败"
                yum clean all
                yum makecache
                yum install -y "$package_name" || {
                    # 尝试备选包
                    if [ -n "$fallback_package" ]; then
                        warning_log "尝试安装备选包 $fallback_package..."
                        yum install -y "$fallback_package" || {
                            error_log "$fallback_package 安装也失败"
                            return 1
                        }
                    else
                        return 1
                    fi
                }
            }
            ;;
        "Fedora")
            dnf install -y "$package_name" || {
                error_log "$package_name 安装失败"
                dnf clean all
                dnf makecache
                dnf install -y "$package_name" || {
                    # 尝试备选包
                    if [ -n "$fallback_package" ]; then
                        warning_log "尝试安装备选包 $fallback_package..."
                        dnf install -y "$fallback_package" || {
                            error_log "$fallback_package 安装也失败"
                            return 1
                        }
                    else
                        return 1
                    fi
                }
            }
            ;;
        "Arch")
            pacman -Sy --noconfirm "$package_name" >> "$LOG_FILE" 2>&1 || {
                error_log "$package_name 安装失败"
                # 尝试备选包
                if [ -n "$fallback_package" ]; then
                    warning_log "尝试安装备选包 $fallback_package..."
                    pacman -Sy --noconfirm "$fallback_package" >> "$LOG_FILE" 2>&1 || {
                        error_log "$fallback_package 安装也失败"
                        return 1
                    }
                else
                    return 1
                fi
            }
            ;;
        "OpenWrt")
            opkg install "$package_name" >> "$LOG_FILE" 2>&1 || {
                error_log "$package_name 安装失败"
                # 尝试备选包
                if [ -n "$fallback_package" ]; then
                    warning_log "尝试安装备选包 $fallback_package..."
                    opkg install "$fallback_package" >> "$LOG_FILE" 2>&1 || {
                        error_log "$fallback_package 安装也失败"
                        return 1
                    }
                else
                    return 1
                fi
            }
            ;;
    esac
    
    # 最后再次检查命令是否存在
    if check_command "$tool_name"; then
        success_log "$tool_name 安装成功"
        return 0
    else
        error_log "$tool_name 安装后仍不可用"
        return 1
    fi
}

# 更新软件包列表的函数
update_package_lists() {
    info_log "更新软件包列表..."
    
    case "$OS" in
        "Debian"|"飞牛OS")
            apt-get update -y || {
                warning_log "初次更新失败，尝试修复apt源..."
                apt-get clean || true
                rm -rf /var/lib/apt/lists/* || true
                apt-get update -y || {
                    error_log "更新软件包列表失败，请检查网络连接或源配置"
                    return 1
                }
            }
            ;;
        "CentOS")
            yum clean all
            yum makecache
            ;;
        "Fedora")
            dnf clean all
            dnf makecache
            ;;
        "Arch")
            pacman -Sy --noconfirm >> "$LOG_FILE" 2>&1
            ;;
        "OpenWrt")
            opkg update >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    return 0
}

# 安装系统依赖 - 按需安装模式
install_dependencies() {
    info_log "开始按需检查并安装依赖..."
    
    # 先更新软件包列表
    update_package_lists || {
        warning_log "软件包列表更新失败，尝试继续..."
    }
    
    # 按需安装核心工具
    install_single_dependency "wget" "wget" || {
        error_log "关键工具wget安装失败"
        return 1
    }
    
    install_single_dependency "unzip" "unzip" || {
        error_log "关键工具unzip安装失败"
        return 1
    }
    
    install_single_dependency "curl" "curl" || {
        error_log "关键工具curl安装失败"
        return 1
    }
    
    # 安装基础工具，允许某些失败但记录警告
    install_single_dependency "grep" "grep" || warning_log "grep安装失败，将继续尝试其他依赖"
    install_single_dependency "sed" "sed" || warning_log "sed安装失败，将继续尝试其他依赖"
    
    # 特殊处理awk - 尝试多种可能的实现
    if ! check_command "awk"; then
        info_log "检测到awk未安装，尝试安装..."
        # 对于飞牛OS等特殊系统，直接尝试gawk作为首选
        if [ "$OS" = "飞牛OS" ]; then
            install_single_dependency "awk" "gawk" || {
                warning_log "gawk安装失败，尝试其他awk实现..."
                install_single_dependency "awk" "mawk" || {
                    warning_log "mawk安装失败，尝试最后一种awk实现..."
                    install_single_dependency "awk" "original-awk" || {
                        warning_log "所有awk实现安装失败，将继续运行"
                    }
                }
            }
            
            # 如果安装了gawk但没有awk命令，创建符号链接
            if which gawk >/dev/null && ! which awk >/dev/null; then
                ln -sf "$(which gawk)" "/usr/bin/awk" 2>/dev/null || {
                    warning_log "无法创建awk符号链接"
                }
            fi
        else
            # 其他系统先尝试常规awk包
            install_single_dependency "awk" "awk" || {
                warning_log "awk安装失败，尝试gawk..."
                install_single_dependency "awk" "gawk" || {
                    warning_log "gawk安装失败，将继续运行"
                }
            }
        fi
    fi
    
    # 安装fuse相关包（尝试fuse3，失败则尝试fuse）
    # 优先安装fusermount作为最基础的FUSE依赖，确保兼容性
    if [ "$OS" = "飞牛OS" ] || [ "$OS" = "OpenWrt" ]; then
        # 对于特殊系统，直接尝试安装基础fuse包
        warning_log "特殊系统检测：$OS，优先安装基础fuse包..."
        install_single_dependency "fusermount" "fuse-utils" "fuse" || {
            warning_log "fuse安装失败，将尝试其他方式或继续运行"
            # 即使安装失败，也继续运行，因为某些系统可能内置了fusermount
        }
    else
        # 其他系统先尝试fusermount
        install_single_dependency "fusermount" "fuse" "fuse-utils" || {
            warning_log "fuse安装失败，尝试fuse3..."
            install_single_dependency "fuse3" "fuse3" || {
                warning_log "fuse3安装也失败，将继续运行"
            }
        }
    fi
    
    # 最终验证关键工具是否存在
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
    
    success_log "核心依赖安装成功"
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
    
    # 创建配置文件 - 使用openlist作为remote名称以匹配提示信息
    cat > ~/.config/rclone/rclone.conf << EOF
[openlist]
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

# 挂载WebDAV服务 - 增强版本
mount_webdav() {
    info_log "挂载WebDAV服务到 $MOUNT_POINT..."
    
    # 检查是否已挂载
    if mount | grep -q "$MOUNT_POINT"; then
        info_log "检测到$MOUNT_POINT已挂载，先卸载..."
        umount "$MOUNT_POINT" >> "$LOG_FILE" 2>&1 || {
            warning_log "卸载失败，可能需要强制卸载"
            umount -f "$MOUNT_POINT" >> "$LOG_FILE" 2>&1 || {
                warning_log "强制卸载也失败，将继续尝试挂载"
            }
        }
    fi
    
    # 先检查配置是否正确
    info_log "验证rclone配置..."
    # 使用更通用的ls命令代替lsd，提高兼容性
    # 捕获并处理rclone ls命令可能的错误
    rclone_ls_output=$(rclone ls openlist: -l --max-depth=1 2>&1)
    RCLONE_LS_EXIT=$?
    echo "$rclone_ls_output" >> "$LOG_FILE"
    
    if [ $RCLONE_LS_EXIT -ne 0 ]; then
        # 先检查配置文件是否存在，这是最基础的检查
        if [ ! -f ~/.config/rclone/rclone.conf ] || ! grep -q "\[openlist\]" ~/.config/rclone/rclone.conf; then
            error_log "rclone配置可能不存在或不正确"
            echo "详细错误: 配置文件中未找到openlist远程" >> "$LOG_FILE"
            return 1
        fi
        
        # 配置文件存在，但连接可能有问题
        # 避免使用可能不支持的listremotes命令
        info_log "配置文件存在，尝试直接挂载..."
    fi
    
    # 执行简化的挂载命令
    info_log "执行挂载命令..."
    
    # 简化挂载逻辑，使用最基础的参数
    rclone mount openlist: "$MOUNT_POINT" \
        --umask 0000 \
        --allow-non-empty \
        --daemon >> "$LOG_FILE" 2>&1
    
    # 获取返回值
    MOUNT_RESULT=$?
    
    # 检查挂载是否成功
    if [ $MOUNT_RESULT -eq 0 ]; then
        # 等待挂载完成
        info_log "等待挂载完成..."
        sleep 3
        
        if mount | grep -q "$MOUNT_POINT"; then
            success_log "WebDAV服务挂载成功!"
            return 0
        else
            error_log "挂载失败，挂载点未出现在挂载列表中"
            # 检查是否有rclone进程在运行
            if pgrep -f "rclone mount" >/dev/null; then
                warning_log "发现rclone进程在运行但挂载未成功，可能是权限问题"
            fi
            # 尝试获取更多错误信息
        info_log "尝试获取更详细的挂载错误信息..."
        rclone mount openlist: "$MOUNT_POINT" \
            --umask 0000 \
            --allow-non-empty \
            --verbose >> "$LOG_FILE" 2>&1 &
            
            # 给进程一点时间输出错误
            sleep 2
            # 杀掉测试进程
            pkill -f "rclone mount openlist:" || true
            
            return 1
        fi
    else
        error_log "挂载命令执行失败，返回码: $MOUNT_RESULT"
        # 简化错误处理
        info_log "尝试不带daemon模式运行以获取详细错误..."
        rclone mount openlist: "$MOUNT_POINT" \
            --umask 0000 \
            --allow-non-empty \
            --verbose >> "$LOG_FILE" 2>&1 &
        
        # 给进程一点时间输出错误
        sleep 2
        # 杀掉测试进程
        pkill -f "rclone mount openlist:" || true
        
        # 简化检查
        if ! check_command fusermount; then
            warning_log "未找到fusermount命令，可能是fuse安装不完整"
        
        return 1
    fi
}

# 设置自动启动 - 更新为使用openlist remote
setup_autostart() {
    info_log "设置自动启动..."
    
    # 创建启动脚本
    AUTOSTART_SCRIPT="/etc/init.d/rclone_openlist"

    if [ "$OS" = "OpenWrt" ] || [ "$OS" = "飞牛OS" ]; then
        # OpenWrt/飞牛OS使用procd - 简化版本
        cat > "$AUTOSTART_SCRIPT" << EOF
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    sleep 30
    $(command -v rclone) mount openlist: "$MOUNT_POINT" \
        --umask 0000 \
        --allow-non-empty \
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
ExecStart=/bin/bash -c '$(command -v rclone) mount openlist: "$MOUNT_POINT" --umask 0000 --allow-non-empty || $(command -v rclone) mount openlist: "$MOUNT_POINT" --umask 0000 --allow-other --allow-non-empty'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
            
            # 启用并启动服务
            systemctl daemon-reload
            systemctl enable rclone-openlist.service
        else
            # 使用init.d - 简化版本
        cat > "$AUTOSTART_SCRIPT" << EOF
#!/bin/bash

case "\$1" in
    start)
        sleep 30
        $(command -v rclone) mount openlist: "$MOUNT_POINT" \
            --umask 0000 \
            --allow-non-empty \
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
    
    # 简化的crontab保障机制
    CRONTAB_ENTRY="@reboot sleep 60 && $(command -v rclone) mount openlist: \"$MOUNT_POINT\" --umask 0000 --allow-non-empty --daemon"
    
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
    
    # 直接使用明文密码，不做任何加密处理
    WEBDAV_PASS_ENCRYPTED="$WEBDAV_PASS"
    info_log "使用明文密码配置rclone"
    
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

# 更新脚本函数
update_script() {
    clear
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}            脚本更新功能                      ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo -e "请选择更新方式:"
    echo -e "${BLUE}1.${NC} 方法1: GitHub原始地址 (不检查SSL证书)"
    echo -e "${BLUE}2.${NC} 方法2: CDN下载 (推荐)"
    echo -e "${BLUE}3.${NC} 方法3: GitHub代理地址"
    echo -e "${BLUE}4.${NC} 手动输入脚本地址"
    echo -e "${GREEN}============================================${NC}"
    
    local auto_restart=false
    
    while true; do
        read -p "请选择更新方式 [1-4]: " update_choice
        
        case $update_choice in
            1)
                SCRIPT_URL="https://raw.githubusercontent.com/jjsxjxj/rclone--OpenList/main/rclone_openlist_mount_linux.sh"
                WGET_OPTS="--no-check-certificate"
                break
                ;;
            2)
                SCRIPT_URL="https://cdn.jsdelivr.net/gh/jjsxjxj/rclone--OpenList@main/rclone_openlist_mount_linux.sh"
                WGET_OPTS="--no-check-certificate"
                break
                ;;
            3)
                # 方法3: 尝试多个GitHub代理
                SCRIPT_URL="https://gh.api.99988866.xyz/https://raw.githubusercontent.com/jjsxjxj/rclone--OpenList/main/rclone_openlist_mount_linux.sh"
                WGET_OPTS="--no-check-certificate"
                break
                ;;
            4)
                echo -e "请输入自定义脚本下载地址:"
                read -p "脚本地址: " SCRIPT_URL
                WGET_OPTS=""
                break
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入${NC}"
                ;;
        esac
    done
    
    # 询问是否更新后自动重新运行
    echo -e "${GREEN}============================================${NC}"
    read -p "更新完成后是否自动重新运行脚本? (y/n): " restart_choice
    if [ "$restart_choice" = "y" ] || [ "$restart_choice" = "Y" ]; then
        auto_restart=true
    fi
    
    # 验证URL不为空
    if [ -z "$SCRIPT_URL" ]; then
        error_log "脚本地址不能为空"
        echo -e "${RED}错误: 脚本地址不能为空${NC}"
        return 1
    fi
    
    # 保存当前脚本名称
    CURRENT_SCRIPT_NAME=$(basename "$0")
    TEMP_SCRIPT="/tmp/${CURRENT_SCRIPT_NAME}.new"
    
    echo -e "${BLUE}正在下载最新脚本...${NC}"
    info_log "开始下载脚本: $SCRIPT_URL"
    
    # 尝试使用wget或curl下载
    if check_command wget; then
        # 使用预设的wget选项
        wget -q -O "$TEMP_SCRIPT" $WGET_OPTS "$SCRIPT_URL" || {
            error_log "wget下载失败"
            echo -e "${RED}错误: wget下载脚本失败${NC}"
            
            # 如果是方法3，尝试备用代理
            if [ "$update_choice" = "3" ]; then
                echo -e "${BLUE}尝试备用GitHub代理...${NC}"
                SCRIPT_URL="https://raw.fastgit.org/jjsxjxj/rclone--OpenList/main/rclone_openlist_mount_linux.sh"
                wget -q -O "$TEMP_SCRIPT" $WGET_OPTS "$SCRIPT_URL" || {
                    error_log "备用代理下载也失败"
                    echo -e "${RED}错误: 备用代理下载也失败${NC}"
                    return 1
                }
            else
                return 1
            fi
        }
    elif check_command curl; then
        # curl不使用SSL检查选项
        curl -s -o "$TEMP_SCRIPT" "$SCRIPT_URL" || {
            # 如果失败且支持SSL选项，尝试不检查SSL
            curl -s -k -o "$TEMP_SCRIPT" "$SCRIPT_URL" || {
                error_log "curl下载失败"
                echo -e "${RED}错误: curl下载脚本失败${NC}"
                return 1
            }
        }
    else
        error_log "wget和curl都不可用"
        echo -e "${RED}错误: wget和curl都不可用，无法下载脚本${NC}"
        return 1
    fi
    
    # 检查下载的文件大小
    if [ ! -s "$TEMP_SCRIPT" ]; then
        error_log "下载的脚本文件为空"
        echo -e "${RED}错误: 下载的脚本文件为空${NC}"
        rm -f "$TEMP_SCRIPT"
        return 1
    fi
    
    # 检查文件是否为有效的bash脚本（简单检查）
    if ! grep -q "^#!/bin/bash" "$TEMP_SCRIPT"; then
        warning_log "下载的文件可能不是有效的bash脚本"
        echo -e "${YELLOW}警告: 下载的文件可能不是有效的bash脚本${NC}"
        echo -e "但仍将继续更新过程..."
    fi
    
    # 设置可执行权限
    chmod +x "$TEMP_SCRIPT" || {
        warning_log "设置执行权限失败"
        echo -e "${YELLOW}警告: 设置脚本执行权限失败${NC}"
    }
    
    # 备份当前脚本
    CURRENT_SCRIPT_PATH="$(readlink -f "$0")"
    BACKUP_SCRIPT="${CURRENT_SCRIPT_PATH}.bak.$(date +%Y%m%d%H%M%S)"
    
    echo -e "${BLUE}正在备份当前脚本...${NC}"
    info_log "备份当前脚本到: $BACKUP_SCRIPT"
    
    cp "$CURRENT_SCRIPT_PATH" "$BACKUP_SCRIPT" || {
        warning_log "备份脚本失败，但将继续更新"
        echo -e "${YELLOW}警告: 备份脚本失败，但将继续更新${NC}"
    }
    
    # 替换当前脚本
    echo -e "${BLUE}正在更新脚本...${NC}"
    info_log "使用新脚本替换当前脚本"
    
    # 尝试使用cp和mv两种方式确保更新成功
    cp "$TEMP_SCRIPT" "$CURRENT_SCRIPT_PATH.new" && \
    mv -f "$CURRENT_SCRIPT_PATH.new" "$CURRENT_SCRIPT_PATH" || {
        error_log "更新脚本失败"
        echo -e "${RED}错误: 更新脚本失败${NC}"
        rm -f "$TEMP_SCRIPT" "$CURRENT_SCRIPT_PATH.new"
        echo -e "${BLUE}尝试使用备用方法更新...${NC}"
        # 备用方法：直接尝试覆盖
        cat "$TEMP_SCRIPT" > "$CURRENT_SCRIPT_PATH" || {
            error_log "所有更新方法都失败"
            echo -e "${RED}错误: 所有更新方法都失败${NC}"
            echo -e "${BLUE}您可以手动使用以下命令更新:${NC}"
            echo -e "cp '$TEMP_SCRIPT' '$CURRENT_SCRIPT_PATH'"
            return 1
        }
    }
    
    # 清理临时文件
    rm -f "$TEMP_SCRIPT"
    
    success_log "脚本更新成功"
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}脚本更新成功！${NC}"
    echo -e "备份文件已保存至: $BACKUP_SCRIPT"
    
    # 自动重新运行脚本
    if [ "$auto_restart" = true ]; then
        echo -e "${BLUE}即将自动重新运行脚本...${NC}"
        echo -e "${GREEN}============================================${NC}"
        sleep 2
        
        # 保存当前脚本路径
        CURRENT_SCRIPT_PATH="$(readlink -f "$0")"
        
        # 重新执行脚本
        info_log "自动重新运行脚本: $CURRENT_SCRIPT_PATH"
        exec "$CURRENT_SCRIPT_PATH"
        # 如果exec失败，才会执行下面的代码
        echo -e "${RED}错误: 自动重新运行脚本失败${NC}"
        error_log "自动重新运行脚本失败"
    else
        echo -e "请手动重新运行脚本以应用新功能。"
        echo -e "${GREEN}============================================${NC}"
    fi
    
    return 0
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
        echo -e "${BLUE}6.${NC} 更新脚本"
        echo -e "${BLUE}7.${NC} 退出"
        echo -e "${GREEN}============================================${NC}"
        read -p "请选择操作 [1-7]: " choice
        
        case $choice in
            1)
                main
                read -p "按Enter键返回菜单..."
                ;;
            2)
                echo -e "重新挂载WebDAV..."
                # 读取配置信息
                if [ -f ~/.config/rclone/rclone.conf ]; then
                    # 优先查找openlist remote，兼容旧的webdav remote
                    if grep -q "\[openlist\]" ~/.config/rclone/rclone.conf; then
                        WEBDAV_URL=$(grep -A 4 "\[openlist\]" ~/.config/rclone/rclone.conf | grep "url =" | cut -d'=' -f2 | tr -d ' ')
                        WEBDAV_USER=$(grep -A 4 "\[openlist\]" ~/.config/rclone/rclone.conf | grep "user =" | cut -d'=' -f2 | tr -d ' ')
                        WEBDAV_PASS_ENCRYPTED=$(grep -A 4 "\[openlist\]" ~/.config/rclone/rclone.conf | grep "pass =" | cut -d'=' -f2 | tr -d ' ')
                        info_log "使用openlist remote配置"
                    elif grep -q "\[webdav\]" ~/.config/rclone/rclone.conf; then
                        WEBDAV_URL=$(grep -A 4 "\[webdav\]" ~/.config/rclone/rclone.conf | grep "url =" | cut -d'=' -f2 | tr -d ' ')
                        WEBDAV_USER=$(grep -A 4 "\[webdav\]" ~/.config/rclone/rclone.conf | grep "user =" | cut -d'=' -f2 | tr -d ' ')
                        WEBDAV_PASS_ENCRYPTED=$(grep -A 4 "\[webdav\]" ~/.config/rclone/rclone.conf | grep "pass =" | cut -d'=' -f2 | tr -d ' ')
                        info_log "使用webdav remote配置"
                    else
                        error_log "未找到openlist或webdav remote配置"
                        read -p "按Enter键返回菜单..."
                        continue
                    fi
                    
                    MOUNT_POINT=$(mount | grep "rclone" | awk '{print $3}' || echo "/mnt/openlist")
                    CHUNK_SIZE="64M" # 默认值
                    
                    # 卸载并重新挂载
                    umount "$MOUNT_POINT" 2>/dev/null || true
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
                update_script
                read -p "按Enter键返回菜单..."
                ;;
            7)
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
