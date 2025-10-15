#!/bin/bash
JUPYTER_TOKEN="${JUPYTER_TOKEN:=huggingface}"
FC_TOKEN="${FC_TOKEN:=FC_TOKEN}"
# nohup python /data/app.py > /dev/null 2>&1 &
ls /

# nohup /fff.sh > /dev/null 2>&1 &
# echo "等待60秒"
# sleep 60
# ls
# /home/vncuser/ff.sh
# jupyter lab \
#     --ip=0.0.0.0 \
#     --port=7860 \
#     --no-browser \
#     --allow-root \
#     --notebook-dir=/data \
#     --ServerApp.token="$JUPYTER_TOKEN" \
#     --ServerApp.disable_check_xsrf=True
/fff.sh
# nohup /fff.sh > /dev/null 2>&1 &
echo "等待 profiles.ini 文件出现..."

# 设置最大等待时间和计数器
max_wait=300  # 最大等待300秒（5分钟）
wait_interval=5  # 每5秒检查一次
elapsed=0

# 循环等待 profiles.ini 文件出现
while [ $elapsed -lt $max_wait ]; do
    if [ -f "/data/ff/.mozilla/firefox/profiles.ini" ]; then
        echo "✅ profiles.ini 文件已出现，执行 ff.sh"
        /home/vncuser/ff.sh
        break
    else
        echo "⏳ 等待 profiles.ini 文件... (已等待 ${elapsed}秒)"
        echo "/data/"
        ls /data/
        echo "/data/ff"
        ls /data/ff/
        echo "/data/ff/.mozilla"
        ls /data/ff/.mozilla/
        echo "/data/ff/.mozilla/firefox"
        ls /data/ff/.mozilla/firefox/
        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))
    fi
done

# 检查是否超时
if [ $elapsed -ge $max_wait ]; then
    echo "❌ 等待超时，profiles.ini 文件未在 ${max_wait} 秒内出现"
    echo "⚠️  尝试直接执行 ff.sh"
    /home/vncuser/ff.sh
fi
