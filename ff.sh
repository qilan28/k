#!/bin/bash
#kill -TERM 1166
# chmod +x ff.sh a.sh
# pkill -TERM -f firefox
# 配置环境变量
export PORT=${PORT:-"7861"}
export VNC_PASSWORD=${VNC_PASSWORD:-"123456"}
export RESOLUTION=${RESOLUTION:-"1280x720"}
export LANG=${LANG:-"zh_CN.UTF-8"}
export DISPLAY=:0
export HOME=/data/ff
export USER=vncuser
export TMPDIR=/data/ff/tmp

# 设置中文环境
export LC_ALL=$LANG
export LANGUAGE=zh_CN:zh
export DBUS_SESSION_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket

# 进程ID变量
XVFB_PID=""
FLUXBOX_PID=""
X11VNC_PID=""
NOVNC_PID=""
FIREFOX_PID=""

# 安全退出函数
cleanup() {
    echo "🛑 收到退出信号，开始清理进程..."
    
    # 发送终止信号给所有进程（从最外层到最内层）
    echo "🔴 终止 Firefox..."
    pkill -TERM -f firefox 2>/dev/null || true
    sleep 2
    
    echo "🔴 终止 noVNC..."
    [ -n "$NOVNC_PID" ] && kill -TERM $NOVNC_PID 2>/dev/null || true
    pkill -TERM -f websockify 2>/dev/null || true
    sleep 2
    
    echo "🔴 终止 x11vnc..."
    [ -n "$X11VNC_PID" ] && kill -TERM $X11VNC_PID 2>/dev/null || true
    pkill -TERM -f x11vnc 2>/dev/null || true
    sleep 2
    
    echo "🔴 终止 Fluxbox..."
    [ -n "$FLUXBOX_PID" ] && kill -TERM $FLUXBOX_PID 2>/dev/null || true
    pkill -TERM -f fluxbox 2>/dev/null || true
    sleep 2
    
    echo "🔴 终止 Xvfb..."
    [ -n "$XVFB_PID" ] && kill -TERM $XVFB_PID 2>/dev/null || true
    pkill -TERM -f Xvfb 2>/dev/null || true
    sleep 3
    
    # 强制清理残留进程
    echo "🧹 强制清理残留进程..."
    pkill -KILL -f firefox 2>/dev/null || true
    pkill -KILL -f websockify 2>/dev/null || true
    pkill -KILL -f x11vnc 2>/dev/null || true
    pkill -KILL -f fluxbox 2>/dev/null || true
    pkill -KILL -f Xvfb 2>/dev/null || true
    
    # 清理锁文件
    echo "🧹 清理锁文件..."
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
    rm -f /data/ff/.Xauthority 2>/dev/null || true
    
    echo "✅ 所有进程清理完成"
    exit 0
}

# 注册信号处理
trap cleanup SIGTERM SIGINT EXIT

# 设置VNC密码
echo "设置VNC密码..."
mkdir -p /data/ff/.vnc
echo "$VNC_PASSWORD" | x11vnc -storepasswd - > /data/ff/.vnc/passwd
chmod 600 /data/ff/.vnc/passwd

# 清理旧的锁文件
echo "清理旧的X11锁文件..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
rm -f /data/ff/.Xauthority 2>/dev/null || true

# 解析分辨率
IFS='x' read -ra RES <<< "$RESOLUTION"
VNC_WIDTH="${RES[0]}"
VNC_HEIGHT="${RES[1]}"
VNC_DEPTH="24"

echo "分辨率: ${VNC_WIDTH}x${VNC_HEIGHT}"

# 创建必要的目录
mkdir -p /data/ff/.mozilla/firefox/default
mkdir -p /data/ff/tmp

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

# 启动Firefox
start_firefox() {
    echo "🚀 启动Firefox浏览器..."
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_ALL=zh_CN.UTF-8
    firefox --name=ff --display=:0 --width=${VNC_WIDTH} --height=${VNC_HEIGHT} https://nav.eooce.com >/dev/null 2>&1 &
    FIREFOX_PID=$!
    sleep 5
    
    if kill -0 $FIREFOX_PID 2>/dev/null; then
        echo "✅ Firefox 启动成功 (PID: $FIREFOX_PID)"
        return 0
    else
        echo "❌ Firefox 启动失败"
        return 1
    fi
}

# 检查Firefox进程
FIREFOX_PID=$(pgrep -f firefox | head -1 || true)
if [ -n "$FIREFOX_PID" ]; then 
    echo "✅ Firefox 运行中 (PID: $FIREFOX_PID)"
else
    echo "⚠️  Firefox 未运行，尝试手动启动..."
    if start_firefox; then
        echo "✅ Firefox 启动成功"
    else
        echo "❌ Firefox 启动失败，将在监控循环中重试"
    fi
fi

# 主进程保持运行
echo "🔄 进入主循环监控..."
while true; do
    # 检查关键进程是否存活
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "❌ Xvfb 进程已停止，执行清理后退出"
        cleanup
    fi
    
    if ! kill -0 $X11VNC_PID 2>/dev/null; then
        echo "❌ x11vnc 进程已停止，执行清理后退出"
        cleanup
    fi
    
    if ! kill -0 $NOVNC_PID 2>/dev/null; then
        echo "❌ noVNC 进程已停止，执行清理后退出"
        cleanup
    fi
    
    # 如果Firefox退出，尝试重新启动
    if ! pgrep -f firefox > /dev/null; then
        echo "⚠️  Firefox 已停止，尝试重新启动..."
        if start_firefox; then
            echo "✅ Firefox 重启成功"
        else
            echo "❌ Firefox 重启失败，稍后重试"
        fi
    fi
    
    # 每60秒检查一次（更频繁的监控）
    sleep 60
done
