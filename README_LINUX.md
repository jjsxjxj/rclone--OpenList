# Rclone OpenList WebDAV 一键配置脚本

## 功能介绍

本脚本用于在Linux系统上一键安装rclone、配置并挂载OpenList的WebDAV服务，支持用户自定义WebDAV地址、账号密码、挂载点、分片大小等参数。

### 核心功能

- **跨平台兼容性**：支持Debian/Ubuntu、CentOS/RHEL、Fedora、Arch Linux以及飞牛OS/OpenWrt
- **环境自动检测与修复**：自动检测系统环境，安装必要依赖
- **日志记录**：详细记录操作过程，便于故障排查
- **用户友好界面**：提供菜单式操作，简单易用
- **WebDAV地址/账号/密码自定义**：简化配置过程
- **用户自定义挂载地址**：灵活设置挂载点
- **分片大小用户自定义**：根据网络情况调整分片大小
- **自动挂载功能**：支持开机延迟30秒自动挂载
- **多重自启动保障**：使用多种机制确保系统重启后自动运行

## 系统要求

- Linux系统 (Debian/Ubuntu、CentOS/RHEL、Fedora、Arch Linux、飞牛OS/OpenWrt)
- 网络连接
- root或sudo权限（建议）

## 使用方法

### 1. 下载脚本

```bash
wget https://example.com/rclone_openlist_mount_linux.sh
```

或者直接复制本仓库中的脚本文件到您的服务器。

### 2. 设置执行权限

```bash
chmod +x rclone_openlist_mount_linux.sh
```

### 3. 运行脚本

```bash
./rclone_openlist_mount_linux.sh
```

### 4. 菜单操作说明

脚本启动后会显示菜单，您可以选择以下操作：

- **1. 全新安装配置**：首次使用时选择，会引导您完成所有配置
- **2. 重新挂载WebDAV**：当挂载失效时使用
- **3. 卸载WebDAV**：临时卸载挂载点
- **4. 查看挂载状态**：检查当前挂载情况
- **5. 查看日志**：查看最近的操作日志
- **6. 退出**：退出脚本

## 配置说明

运行全新安装配置时，您需要输入以下信息：

- **WebDAV地址**：OpenList的WebDAV服务地址，例如 `https://example.com/dav`
- **WebDAV用户名**：访问WebDAV服务的用户名
- **WebDAV密码**：访问WebDAV服务的密码（输入时不显示）
- **挂载点路径**：默认为 `/mnt/openlist`，可自定义
- **分片大小**：默认为 `64M`，可根据网络情况选择 `32M/64M/128M/256M`

## 自动启动机制

脚本会根据您的系统类型自动选择合适的自启动方式：

- **Systemd系统**：创建systemd服务并启用
- **OpenWrt系统**：使用procd启动系统
- **其他系统**：使用init.d脚本
- **通用保障**：额外添加crontab @reboot任务作为双重保障

所有自启动机制都会在系统启动后延迟30秒执行，确保网络服务已就绪。

## 常见问题

### 1. 挂载失败怎么办？

- 检查WebDAV地址、用户名和密码是否正确
- 检查网络连接是否正常
- 查看日志文件 `rclone_openlist_setup.log` 获取详细错误信息
- 尝试使用 `--allow-other` 选项（脚本已包含）

### 2. 自动启动不生效怎么办？

- 检查对应的系统服务状态
- 查看crontab是否正确设置：`crontab -l`
- 手动执行启动命令测试

### 3. 权限问题

- 确保以root用户或具有sudo权限的用户运行脚本
- 检查挂载点目录的权限设置

## 日志文件

脚本会在当前目录生成 `rclone_openlist_setup.log` 文件，记录所有操作过程和错误信息。您可以使用以下命令查看日志：

```bash
cat rclone_openlist_setup.log
# 或查看最近的日志
tail -n 100 rclone_openlist_setup.log
```

## 手动管理

### 手动挂载

```bash
rclone mount openlist: /mnt/openlist --daemon
```

### 手动卸载

```bash
umount /mnt/openlist
```

### 查看rclone版本

```bash
rclone version
```

## 注意事项

1. 请确保您的WebDAV服务地址正确无误
2. 建议在服务器环境下使用，不建议在个人电脑上长期挂载
3. 对于高流量场景，建议适当调整分片大小和缓存设置
4. 定期检查挂载状态，确保服务正常运行

## 免责声明

本脚本仅供学习和测试使用，请确保您有权限访问和使用相关的WebDAV服务。使用本脚本产生的一切后果由用户自行承担。

## 更新日志

### v1.0
- 初始版本
- 支持多种Linux发行版
- 实现所有核心功能

## 许可证

本项目采用MIT许可证。