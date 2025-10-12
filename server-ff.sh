#!/bin/bash
JUPYTER_TOKEN="${JUPYTER_TOKEN:=huggingface}"
# wget -O "ff.py" "https://raw.githubusercontent.com/qilan28/k/refs/heads/main/ff.py"
# source /opt/venv/bin/activate
# nohup python /data/app.py > /data/app.log 2>&1 &
# nohup python /data/app.py > /dev/null 2>&1 &
nohup /fff.sh > /dev/null 2>&1 &
# ls
# python ff.py
echo "等待60秒"
# sleep 30
ls
/home/vncuser/ff.sh
# jupyter lab \
#     --ip=0.0.0.0 \
#     --port=7860 \
#     --no-browser \
#     --allow-root \
#     --notebook-dir=/data \
#     --ServerApp.token="$JUPYTER_TOKEN" \
#     --ServerApp.disable_check_xsrf=True
