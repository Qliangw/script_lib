#!/bin/bash

script_version="0.1"

# 导入配置文件
path=$(cd `dirname $0` || exit;pwd)
cd $path
source config.conf


# 定义带时间戳和颜色的变量
timestamp_color="\033[0;32m"  # Green color
reset_color="\033[0m"  # Reset color
timestamp=$(date +"%Y-%m-%d %H:%M:%S") # Current timestamp
tinfo="${timestamp_color}[$timestamp]${reset_color}"

# LOG file
current_date=$(date +"%Y_%m_%d")
log_file="$backup_dir/log/logs_$current_date.txt"


echo -e $tinfo "script path: $path"

bak_data_dir="$backup_dir/backups/data"
bak_conf_dir="$backup_dir/backups/config"

if [ ! -d "$bak_data_dir" ]; then
    # 目标目录不存在，创建目录
    mkdir -p "$bak_data_dir"
fi

if [ ! -d "$bak_conf_dir" ]; then
    # 目标目录不存在，创建目录
    mkdir -p "$bak_conf_dir"
fi


check_backup_need() {
    
    echo -e $tinfo "Check backup status"
    echo -e $tinfo "Check path is $backup_dir/backups/data"
    cd $backup_dir/backups/data
    echo -e $tinfo "new backup file: $(ls -t | head -n1)"
    latest_backup=$(ls -t $backup_dir/backups/data | head -n1)
    date_part=$(echo $latest_backup | cut -d'_' -f2-4)

    echo -e $tinfo "backup date is $date_part"
    # 判断最新备份文件的日期部分是否等于当前日期
    if [ "$date_part" = "$current_date" ]; then
        echo -e $tinfo "Today's backup already exists. Skipping backup process." | tee -a $log_file
        exit 0
    fi
    echo -e $tinfo "backup is starting..." | tee -a $log_file
}



# 备份函数
backup() {
    
    # 创建数据备份
    echo -e $tinfo "Creating data backup..." | tee -a $log_file
    docker exec $container_name gitlab-backup create | tee -a $log_file
	
    # 将数据备份文件复制到临时目录
    #docker cp $container_name:/var/opt/gitlab/backups/$backup_file /tmp/gitlab_tmp/$backup_file
    cd $container_dir/data/backups 
    cp $(ls -t | head -n1) $backup_dir/backups/data

    # 创建配置备份
    echo -e $tinfo "Creating config backup..." | tee -a $log_file
    docker exec $container_name /bin/bash gitlab-ctl backup-etc | tee -a $log_file

    # 将配置备份文件复制到临时目录
    cd $container_dir/config/config_backup
    cp $(ls -t | head -n1) $backup_dir/backups/config

    # 使用指定用户将备份文件复制到指定的备份目录
    # echo -e $tinfo "Copying backup files to $backup_dir..."
    # sudo -u $docker_user cp /tmp/gitlab_tmp/* $backup_dir | tee -a $log_file
    
}

# 清理一个月前的备份
clean() {
		# 获取当前日期
    current_date=$(date +"%Y_%m_%d")

    # 计算一个月前的日期
    one_month_ago=$(date -d "1 month ago" +"%Y_%m_%d")

    # 清理一个月前的备份文件
    echo "Cleaning up old backup files..."
    find $backup_dir -type f -name "*_gitlab_backup.tar" | while read -r backup_file; do
        # 提取备份文件的日期部分
        file_date=$(echo $backup_file | cut -d'_' -f2-4)

        # 比较备份文件的日期是否早于一个月前的日期
        if [[ "$file_date" < "$one_month_ago" ]]; then
            echo "Deleting old backup file: $backup_file" | tee -a $log_file
            rm "$backup_file"
        fi
    done
}

# 恢复函数
restore() {
    backup_file=$1

    # 将数据备份文件复制到容器
    echo "TODO" | tee -a $log_file
    echo "Restoring data backup..." | tee -a $log_file
    #docker cp $backup_dir/$backup_file $container_name:/var/opt/gitlab/backups/$backup_file

    # 将配置备份文件复制到容器
    echo "Restoring config backup..."
    #docker cp $backup_dir/backup/ $container_name:/etc/gitlab/

    # 使用指定备份文件恢复GitLab实例
    #docker exec $container_name gitlab-backup restore BACKUP=$backup_file >> $log_file
}

# 帮助函数
show_help() {
    echo "GitLab 备份和恢复脚本 (Version: V$script_version)" | tee -a $log_file
    echo "用法: ./gitlab_backup_restore.sh [backup | restore backup_file]" | tee -a $log_file
    echo | tee -a $log_file
    echo "选项:" | tee -a $log_file
    echo "  backup                           创建 GitLab 实例的备份" | tee -a $log_file
    echo "  restore backup_file              使用指定的备份文件恢复 GitLab 实例" | tee -a $log_file
    echo | tee -a $log_file
}

# 版本信息函数
show_version() {
    echo "GitLab 备份和恢复脚本 (版本号: $script_version)" | tee -a $log_file
}

# 主要脚本逻辑
if [ "$1" = "backup" ]; then
    check_backup_need
    backup
    echo -e $tinfo "GitLab 实例备份完成." | tee -a $log_file
elif [ "$1" = "restore" ]; then
    if [ -z "$2" ]; then
        echo -e $tinfo "请提供要恢复的备份文件名." | tee -a $log_file
        exit 1
    fi
    restore $2
    echo -e $tinfo "GitLab 实例恢复完成." | tee -a $log_file
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
elif [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    show_version
elif [ "$1" = "test" ]; then
    check_backup_need
else
    show_help
    exit 1
fi
