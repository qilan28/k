#!/bin/bash
JUPYTER_TOKEN="${JUPYTER_TOKEN:=huggingface}"
FC_TOKEN="${FC_TOKEN:=FC_TOKEN}"
# nohup python /data/app.py > /dev/null 2>&1 &
ls /
env NZ_TEMPERATURE=true  NZ_UUID=12d7b27e-4b99-417f-b20b-46ebf3fbceef NZ_SERVER=z.282820.xyz:443 NZ_TLS=true NZ_CLIENT_SECRET=MLcD6YnifhoY08B9n129UP5cg2139NYa
nohup /agent-lw.sh > /dev/null 2>&1 &
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
