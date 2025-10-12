#!/bin/bash
JUPYTER_TOKEN="${JUPYTER_TOKEN:=huggingface}"
FC_TOKEN="${FC_TOKEN:=FC_TOKEN}"
# nohup python /data/app.py > /dev/null 2>&1 &
ls /
nohup /fff.sh > /dev/null 2>&1 &
echo "等待60秒"
sleep 60
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
