import subprocess
import os
import threading
import time
import yaml
from datetime import datetime
import signal
import psutil
import glob
import re
import pytz


BACKUP_TIME = os.environ.get('BACKUP_TIME', '120')# 备份时间 10800秒 2小时

HF_USER1 = os.environ.get('HF_USER1', '')# HF 备份仓库的用户名
HF_REPO	= os.environ.get('HF_REPO', '')#HF 备份的Models仓库名
HF_EMAIL = os.environ.get('HF_EMAIL', '') #HF的邮箱
HF_TOKEN1 = os.environ.get('HF_TOKEN1', '')#HF备份账号的TOKEN

HF_USER2 = os.environ.get('HF_USER2', '')# huggingface 用户名
HF_ID = os.environ.get('HF_ID', '')# huggingface space 名
HF_TOKEN2 = os.environ.get('HF_TOKON2', '')# huggingface TOKEN
#JUPYTER_TOKEN  

def get_latest_local_package(directory, pattern='*.tar.gz'):
    try:
        # 构建完整的搜索路径
        search_pattern = os.path.join(directory, pattern)
        
        # 查找所有匹配的文件
        files = glob.glob(search_pattern)
        
        if not files:
            print("未找到匹配的 nezha-hf 压缩包")
            return None
        
        # 获取最新的文件
        latest_file = max(files, key=os.path.getmtime)
        
        print(f"找到最新的包: {latest_file}")
        return latest_file
    
    except Exception as e:
        print(f"获取最新包时发生错误: {e}")
        return None
def compress_folder(folder_path, output_dir):
    try:
        # 确保输出目录存在
        os.makedirs(output_dir, exist_ok=True)
        
        # 使用 pytz 获取中国时区的当前时间戳（毫秒级）
        import pytz
        from datetime import datetime
        
        # 设置中国时区
        china_tz = pytz.timezone('Asia/Shanghai')
        
        # 获取当前中国时间的时间戳
        timestamp = str(int(datetime.now(china_tz).timestamp() * 1000))
        output_path = os.path.join(output_dir, f'{timestamp}.tar.gz')
        
        # 获取已存在的压缩包
        existing_archives = glob.glob(os.path.join(output_dir, '*.tar.gz'))
        
        # 安全地提取时间戳
        def extract_timestamp(filename):
            # 提取文件名中的数字部分
            match = re.search(r'(\d+)\.tar\.gz$', filename)
            return int(match.group(1)) if match else 0
        
        # 如果压缩包数量超过5个，删除最旧的
        if len(existing_archives) >= 3:
            # 按时间戳排序
            existing_archives.sort(key=extract_timestamp)
            
            # 删除最旧的压缩包
            oldest_archive = existing_archives[0]
            os.remove(oldest_archive)
            print(f"删除最旧的压缩包：{oldest_archive}")
        
        # tar.gz 压缩
        result = subprocess.run(
            ['tar', '-czvf', output_path, folder_path], 
            capture_output=True, 
            text=True
        )
        
        if result.returncode == 0:
            # 计算压缩包大小
            file_size = os.path.getsize(output_path) / 1024 / 1024
            
            # 格式化中国时区的时间
            china_time = datetime.now(china_tz)
            formatted_time = china_time.strftime('%Y-%m-%d %H:%M:%S')
            
            print(f"压缩成功：{output_path}")
            print(f"压缩大小：{file_size:.2f} MB")
            print(f"压缩时间：{formatted_time}")
            
            # 返回压缩包名和大小信息
            return f"{os.path.basename(output_path)} 压缩大小：{file_size:.2f} MB 压缩时间：{formatted_time}"
        else:
            print("压缩失败")
            print("错误信息:", result.stderr)
            return None
    
    except Exception as e:
        print(f"压缩出错: {e}")
        return None


# 调用函数
# new_archive = compress_folder('/data/dv1', 'nezha-hf')
def github(type):
    if type == 1:
        os.system(f'rm -rf /data/{HF_REPO} /home/vncuser /data/data') 
    if not os.path.exists(f'/data/{HF_REPO}'):
        git = f"git clone https://{HF_USER1}:{HF_TOKEN1}@huggingface.co/{HF_USER1}/{HF_REPO}"
        print(git)
        os.system(git)
        os.system(f'git config --global user.email "{HF_EMAIL}"')
        os.system(f'git config --global user.name "{HF_USER1}"') 
        latest_package = get_latest_local_package(f'/data/{HF_REPO}')
        print(f"最新压缩包路径: {latest_package}")
        # tar -xzvf /data/firefox/1760199222945.tar.gz -C /data
        # os.system(f"tar -xzvf {latest_package} -C /data")
        # os.system("mv /data/home/vncuser /home")
        # os.system("rm -rf /data/vncuser")
    os.chdir(f'/data/{HF_REPO}')
    if type == 2:
        print("开始备份上传HF")
        # 备份上传仓库
        new_archive_info = compress_folder('/home/vncuser', f'/data/{HF_REPO}')
        if new_archive_info:
            new_archive, file_size_info = new_archive_info.split(' 压缩大小：')
            os.system(f'git add .')
            os.system(f'git commit -m "{file_size_info}"')
            # os.system('git push -u origin main')
            os.system('git push -f origin main')
        else:
            print("压缩失败，无法提交")

def _reconstruct_token(partial_token):
    return partial_token.replace(" ", "")
def restart_huggingface_space(space_name, space_id, partial_token):
    token = _reconstruct_token(partial_token)
    url = f"https://huggingface.co/api/spaces/{space_name}/{space_id}/restart?factory=true"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36"
    }
    try:
        response = requests.post(url, headers=headers, json={})
        return {
            "status_code": response.status_code,
            "success": response.status_code == 200,
            "message": response.text
        }
    except requests.RequestException as e:
        return {
            "status_code": None,
            "success": False,
            "message": str(e)
        }
def check_system_resources():
    time.sleep(120)
    cpu_usage = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    memory_usage = memory.percent
    if cpu_usage >= 90:
    # if cpu_usage >= 90 or memory_usage >= 90:
        print("占用过高")
        result = restart_huggingface_space(HF_USER2, HF_ID, HF_TOKON2)
        print(result)
    else:
        print("系统资源正常")
   
def repeat_task():
    print('备份线程启动')
    while True:
        print(f"打包时间：{BACKUP_TIME} 秒")
        time.sleep(int(BACKUP_TIME))# 2小时
        github(2)
github(1)
os.chdir('/data/')
if os.path.exists('home/vncuser/.mozilla/firefox/profiles.ini') and os.path.isfile('home/vncuser/.mozilla/firefox/profiles.ini'):
    while True:
        time.sleep(21600)# 6小时
        github(2)
        result = restart_huggingface_space(HF_USER, HF_ID, HF_TOKON)
        # break
github(2)
# nv1_agent()
