#!/bin/bash

# 配置环境变量
export PORT=${PORT:-"7860"}
export VNC_PASSWORD=${VNC_PASSWORD:-"123456"}
export RESOLUTION=${RESOLUTION:-"1280x720"}
export LANG=${LANG:-"zh_CN.UTF-8"}
export DISPLAY=:0
export HOME=/home/vncuser
export USER=vncuser
export TMPDIR=/home/vncuser/tmp

# 设置中文环境
export LC_ALL=$LANG
export LANGUAGE=zh_CN:zh
export DBUS_SESSION_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket

# 创建必要目录
mkdir -p /home/vncuser/.vnc
mkdir -p /home/vncuser/.fluxbox
mkdir -p /home/vncuser/tmp
mkdir -p /tmp/.X11-unix
mkdir -p /home/vncuser/.mozilla/firefox
mkdir -p /var/run/dbus

# 设置权限
chmod 700 /home/vncuser/.vnc
chmod 1777 /tmp/.X11-unix
chmod 700 /home/vncuser/tmp
chmod 755 /var/run/dbus
chown -R vncuser:vncuser /home/vncuser

# 设置VNC密码
echo "设置VNC密码..."
echo "$VNC_PASSWORD" | x11vnc -storepasswd - > /home/vncuser/.vnc/passwd
chmod 600 /home/vncuser/.vnc/passwd

# 清理旧的锁文件
echo "清理旧的X11锁文件..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
rm -f /home/vncuser/.Xauthority 2>/dev/null || true

# 解析分辨率
IFS='x' read -ra RES <<< "$RESOLUTION"
VNC_WIDTH="${RES[0]}"
VNC_HEIGHT="${RES[1]}"
VNC_DEPTH="24"

echo "分辨率: ${VNC_WIDTH}x${VNC_HEIGHT}"

# 创建Firefox配置目录和用户配置文件
mkdir -p /home/vncuser/.mozilla/firefox/default

# 创建Firefox首选项文件，设置中文和主页
cat > /home/vncuser/.mozilla/firefox/profiles.ini << EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=default
IsRelative=1
Path=default
Default=1
EOF

# 创建Fluxbox配置
cat > /home/vncuser/.fluxbox/init << EOF
session.screen0.workspaces: 1
session.screen0.workspacewarping: false
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: true
session.screen0.maxDisableMove: false
session.screen0.maxDisableResize: false
session.screen0.defaultDeco: NONE
EOF

cat > /home/vncuser/.fluxbox/startup << EOF
#!/bin/bash
# Fluxbox启动脚本
# 设置中文环境
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
export DBUS_SESSION_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket

# 等待X服务器完全启动
sleep 3

# 启动Firefox（不使用kiosk模式，使用普通模式）
firefox --name=ff --width=${VNC_WIDTH} --height=${VNC_HEIGHT} https://nav.eooce.com &
EOF

chmod +x /home/vncuser/.fluxbox/startup
chown -R vncuser:vncuser /home/vncuser/.fluxbox
chown -R vncuser:vncuser /home/vncuser/.mozilla

echo "🚀 启动Xvfb显示服务器..."
# 启动Xvfb（显示服务器）
Xvfb :0 -screen 0 ${VNC_WIDTH}x${VNC_HEIGHT}x${VNC_DEPTH} -ac +extension RANDR -nolisten tcp -noreset &
XVFB_PID=$!

# 等待Xvfb启动
sleep 3

# 检查Xvfb是否成功启动
if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "❌ Xvfb启动失败"
    exit 1
fi

echo "✅ Xvfb启动成功 (PID: $XVFB_PID)"

echo "🚀 启动Fluxbox窗口管理器..."
# 启动Fluxbox
fluxbox -display :0 &
FLUXBOX_PID=$!
sleep 3

echo "🚀 启动x11vnc服务器..."
# 启动x11vnc（使用默认端口5900，但只在容器内部访问）
x11vnc -display :0 -forever -shared -passwd "$VNC_PASSWORD" -rfbport 5900 -localhost -noxdamage -xrandr &
X11VNC_PID=$!
sleep 2

echo "🚀 启动noVNC网页客户端..."
# 启动noVNC（作为反向代理，将外部8080端口请求转发到内部5900端口）
websockify --web /usr/share/novnc $PORT localhost:5900 &
NOVNC_PID=$!
sleep 2

echo "等待Firefox启动..."
# 给Fluxbox startup脚本时间启动Firefox
sleep 10

echo "==========================================="
echo "✅ 所有服务启动完成！"
echo "📺 VNC 分辨率: ${RESOLUTION}"
echo "🔑 VNC 密码: ${VNC_PASSWORD}"
echo "🌐 访问地址: http://localhost:${PORT}"
echo "🏠 默认主页: https://nav.eooce.com"
echo "🔤 语言设置: 中文 (简体)"
echo "==========================================="

# 检查所有进程是否在运行
echo "进程状态检查:"
if kill -0 $XVFB_PID 2>/dev/null; then echo "✅ Xvfb 运行中"; else echo "❌ Xvfb 已停止"; fi
if kill -0 $FLUXBOX_PID 2>/dev/null; then echo "✅ Fluxbox 运行中"; else echo "❌ Fluxbox 已停止"; fi
if kill -0 $X11VNC_PID 2>/dev/null; then echo "✅ x11vnc 运行中"; else echo "❌ x11vnc 已停止"; fi
if kill -0 $NOVNC_PID 2>/dev/null; then echo "✅ noVNC 运行中"; else echo "❌ noVNC 已停止"; fi

# 检查Firefox进程
FIREFOX_PID=$(pgrep -f firefox || true)
if [ -n "$FIREFOX_PID" ]; then 
    echo "✅ Firefox 运行中 (PID: $FIREFOX_PID)"
else
    echo "⚠️  Firefox 未运行，尝试手动启动..."
    # 尝试手动启动Firefox
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_ALL=zh_CN.UTF-8
    firefox --name=ff --display=:0 --width=${VNC_WIDTH} --height=${VNC_HEIGHT} https://nav.eooce.com >/dev/null 2>&1 &
    sleep 5
    FIREFOX_PID=$(pgrep -f firefox || true)
    if [ -n "$FIREFOX_PID" ]; then
        echo "✅ Firefox 启动成功 (PID: $FIREFOX_PID)"
    else
        echo "❌ Firefox 启动失败"
        if [ -f /home/vncuser/firefox.log ]; then
            echo "Firefox 错误日志:"
            cat /home/vncuser/firefox.log
        fi
    fi
fi

# 主进程保持运行
echo "🔄 进入主循环..."
while true; do
    # 检查关键进程是否存活
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "❌ Xvfb 进程已停止，退出容器"
        exit 1
    fi
    
    if ! kill -0 $X11VNC_PID 2>/dev/null; then
        echo "❌ x11vnc 进程已停止，退出容器"
        exit 1
    fi
    
    # 如果Firefox退出，尝试重新启动
    if ! pgrep -f firefox > /dev/null; then
        echo "⚠️  Firefox 已停止，尝试重新启动..."
        firefox --name=ff --display=:0 --width=${VNC_WIDTH} --height=${VNC_HEIGHT} >/dev/null 2>&1 &
        sleep 5
    fi
    
    # 每120秒检查一次
    sleep 120
done
