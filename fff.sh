#!/bin/bash

# 环境变量设置
BACKUP_TIME=${BACKUP_TIME:-"120"}
HF_USER1=${HF_USER1:-""}
HF_REPO=${HF_REPO:-""}
HF_EMAIL=${HF_EMAIL:-""}
HF_TOKEN1=${HF_TOKEN1:-""}
HF_USER2=${HF_USER2:-""}
HF_ID=${HF_ID:-""}
HF_TOKEN2=${HF_TOKEN2:-""}

# 获取最新的本地压缩包
get_latest_local_package() {
    local directory="$1"
    local pattern="${2:-"*.tar.gz"}"
    
    # 构建完整的搜索路径
    local search_pattern="${directory}/${pattern}"
    
    # 查找所有匹配的文件并按时间排序
    local latest_file=$(ls -t $search_pattern 2>/dev/null | head -n1)
    
    if [ -z "$latest_file" ]; then
        echo "未找到匹配的 nezha-hf 压缩包" >&2
        return 1
    fi
    
    echo "找到最新的包: $latest_file" >&2
    echo "$latest_file"
    return 0
}

# 压缩文件夹
compress_folder() {
    local folder_path="$1"
    local output_dir="$2"
    
    # 确保输出目录存在
    mkdir -p "$output_dir"
    
    # 获取当前中国时间的时间戳（毫秒级）
    local timestamp=$(date +%s%3N)
    local output_path="${output_dir}/${timestamp}.tar.gz"
    
    # 获取已存在的压缩包并按时间排序
    local existing_archives=($(ls -t ${output_dir}/*.tar.gz 2>/dev/null))
    
    # 如果压缩包数量超过3个，删除最旧的
    if [ ${#existing_archives[@]} -ge 3 ]; then
        # 删除最旧的（列表最后一个）
        local oldest_archive="${existing_archives[${#existing_archives[@]}-1]}"
        rm -f "$oldest_archive"
        echo "删除最旧的压缩包：$oldest_archive" >&2
    fi
    
    # 检查源文件夹是否存在
    if [ ! -d "$folder_path" ]; then
        echo "错误: 源文件夹 $folder_path 不存在" >&2
        return 1
    fi
    
    # tar.gz 压缩
    echo "正在压缩文件夹: $folder_path 到 $output_path" >&2
    if tar -czf "$output_path" -C "$(dirname "$folder_path")" "$(basename "$folder_path")" 2>/dev/null; then
        # 计算压缩包大小
        local file_size=$(du -b "$output_path" | awk '{printf "%.2f", $1/1024/1024}')
        
        # 格式化中国时区的时间
        local formatted_time=$(date '+%Y-%m-%d %H:%M:%S')
        
        echo "压缩成功：$output_path" >&2
        echo "压缩大小：${file_size} MB" >&2
        echo "压缩时间：$formatted_time" >&2
        
        # 返回压缩包名和大小信息
        echo "$(basename "$output_path")|${file_size}|$formatted_time"
        return 0
    else
        echo "压缩失败" >&2
        return 1
    fi
}

# GitHub/HuggingFace 相关操作
github() {
    local type="$1"
    
    if [ "$type" = "1" ]; then
        echo "清理旧文件..."
        rm -rf "/data/${HF_REPO}" "/data/ff" 
    fi
    
    if [ ! -d "/data/${HF_REPO}" ]; then
        echo "克隆仓库..."
        local git_url="https://${HF_USER1}:${HF_TOKEN1}@huggingface.co/${HF_USER1}/${HF_REPO}"
        echo "$git_url"
        git clone "$git_url"
        git config --global user.email "${HF_EMAIL}"
        git config --global user.name "${HF_USER1}"
        echo "当前目录文件:"
        ls -la
        
        local latest_package
        latest_package=$(get_latest_local_package "/data/${HF_REPO}")
        
        # 检查是否找到有效的压缩包
        if [ $? -eq 0 ] && [ -n "$latest_package" ] && [ -f "$latest_package" ]; then
            echo "找到压缩包: $latest_package"
            
            # 解压压缩包
            echo "正在解压..."
            if tar -xzf "$latest_package" -C /data; then
                echo "解压成功"
                # 检查解压后的目录结构
                echo "检查解压结果:"
                ls -la /data/f
                if [ -d "/data/f" ]; then
                    ls -la /data/ff
                fi
                
                if [ -d "/data/f" ]; then
                    mv /data/f/ff /data/
                    echo "移动vncuser完成"
                elif [ -d "/data/f" ]; then
                    mv /data/f/ff /data/
                    echo "移动vncuser完成"
                else
                    echo "警告: 未找到vncuser目录，创建空目录"
                    mkdir -p /data/f
                fi
            else
                echo "解压失败"
            fi
            rm -rf /data/data /data/f 2>/dev/null
        else
            echo "没有找到可用的压缩包，创建空的vncuser目录"
            mkdir -p /data/ff
        fi
    fi
    
    cd "/data/${HF_REPO}" || { echo "无法进入目录 /data/${HF_REPO}"; return 1; }
    
    if [ "$type" = "2" ]; then
        echo "开始备份上传HF"
        mkdir -p /data/f
        cp -rf /data/ff /data/f
        # 备份上传仓库
        local new_archive_info
        new_archive_info=$(compress_folder "/data/f" "/data/${HF_REPO}")
        if [ $? -eq 0 ] && [ -n "$new_archive_info" ]; then
            # 使用 | 分隔符分割信息
            IFS='|' read -r archive_name file_size formatted_time <<< "$new_archive_info"
            
            local commit_message="大小：${file_size} MB 压缩时间：${formatted_time}"
            echo "提交信息: $commit_message"
            
            git add .
            git commit -m "$commit_message"
            git push -f origin main
            echo "备份上传完成"
            rm -rf /data/f
        else
            echo "压缩失败，无法提交"
            rm -rf /data/f
        fi
    fi
}

# 重构token（简化版）
_reconstruct_token() {
    local partial_token="$1"
    echo "$partial_token" | tr -d ' '
}

# 重启HuggingFace Space
restart_huggingface_space() {
    local space_name="$1"
    local space_id="$2"
    local partial_token="$3"
    
    local token=$(_reconstruct_token "$partial_token")
    local url="https://huggingface.co/api/spaces/${space_name}/${space_id}/restart?factory=true"
    
    echo "正在重启Space: ${space_name}/${space_id}"
    
    # 使用curl发送请求
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${token}" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36" \
        "$url")
    
    local http_code=$(echo "$response" | tail -n1)
    local content=$(echo "$response" | head -n -1)
    
    echo "状态码: $http_code"
    echo "响应: $content"
    
    if [ "$http_code" = "200" ]; then
        echo "重启成功"
        return 0
    else
        echo "重启失败"
        return 1
    fi
}

# 检查系统资源
check_system_resources() {
    sleep 120
    
    # 获取CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # 获取内存使用率
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc)
    
    echo "CPU使用率: $cpu_usage%"
    echo "内存使用率: $memory_usage%"
    
    # 使用字符串比较（简化处理）
    if (( $(echo "$cpu_usage >= 90" | bc -l 2>/dev/null || echo "0") )); then
        echo "系统资源占用过高，尝试重启..."
        restart_huggingface_space "$HF_USER2" "$HF_ID" "$HF_TOKEN2"
    else
        echo "系统资源正常"
    fi
}

# 重复任务（对应Python中的repeat_task函数）
repeat_task() {
    echo '备份线程启动'
    while true; do
        echo "打包时间：${BACKUP_TIME} 秒"
        sleep "${BACKUP_TIME}"  # 2小时
        github "2"
    done
}

# 主程序
main() {
    echo "启动备份脚本..."
    
    # 初始设置 - 对应Python中的 github(1)
    github "1"
    
    cd /data/ || { echo "无法进入 /data 目录"; exit 1; }
    
    # 启动重复备份任务（后台运行）
    echo "启动定期备份任务..."
    repeat_task &
    local backup_pid=$!
    
    # 检查是否存在profiles.ini文件
    if [ -f "/home/vncuser/.mozilla/firefox/profiles.ini" ]; then
        echo "检测到Firefox配置，启动定期重启循环..."
        while true; do
            sleep 21600  # 6小时
            echo "执行定期备份和重启..."
            github "2"
            restart_huggingface_space "$HF_USER2" "$HF_ID" "$HF_TOKEN2"
        done
    else
        echo "未检测到Firefox配置，只运行定期备份..."
        # 等待后台任务
        wait $backup_pid
    fi
}

# 启动主程序
main "$@"
# github "2"
