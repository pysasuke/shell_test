#!/bin/bash

# Describe: start/stop java service
# Author : fangxm
# Create : 2017-01-23
# Version: 1.0.1

# history:
# 2017-01-23 1.0.0: support start/stop single service.
# 2017-04-17 1.0.1: support batch start/stop services.

# 全局变量  

PROFILES=devel    #开发环境
#PROFILES=test    #测试环境
#PROFILES=production	#生产环境

ARGS="-Dspring.profiles.active=${PROFILES}"    #启动参数

SERVICES_NUM=0
SERVICES_ARRAY=()
SERVICES_EXTENSION=()
PIDS_ARRAY=()

GREEN_BEGIN="\033[32m"    # 绿色
RED_BEGIN="\033[31m"    # 红色
COLOR_END="\033[0m"    # 关闭所有属性 

# 展示服务列表
list_services() {
	# (与全局变量同名)会覆盖全局变量的值(如果不想影响需用在变量前加local修饰，标记为局部变量)
    SERVICES_NUM=0    
    SERVICES_ARRAY=()    
#    SERVICES_TYPE=()    #未用到
    PIDS_ARRAY=()    

	# grep -Ev '^#|^$'' 文件名
	# -E是扩展的grep，即egrep，使用正则表达式
	# -v是反选，除了匹配正则的行都打印出来
	# 正则：
	# 		^#     以#开头的行
	# 		|      或者	
	#       ^$     空行
    services=`cat list.lst | grep -Ev '^#|^$'`    # 读文件(按正则筛选：去掉以#开头的行和空行)

	
	# 格式: echo -e "\033[字背景颜色;字体颜色m字符串\033[0m" 
    echo ""
    echo -e ${GREEN_BEGIN}" NO SERVICE            PID"${COLOR_END}
    echo -e ${GREEN_BEGIN}" -- ------------------ -----"${COLOR_END}

    for service in ${services}; do
        name=${service%.*}  # %.* 删除最后一个.及其右边的字符串(删除.jar后缀)
        extension=${service##*.}  # ##*. 删掉最后一个 .  及其左边的字符串
		
		#    ps -ef |                         全格式显示当前所有进程
		#    grep 							  过滤/搜索的特定字符
		#    \                                转译符
		#    grep -v grep                     把''grep''这个进程忽略掉
		#    awk '{print $2}'  $fileName :   一行一行的读取指定的文件，以空格作为分隔符，打印第二个字段(PID)
        pid=$(ps -ef | grep "\-jar $service$" | grep -v grep | awk '{ print $2 }')    # 获取指定服务的pid
        
		SERVICES_NUM=$(($SERVICES_NUM+1))  # 自增操作
        SERVICES_ARRAY[$SERVICES_NUM]=${name}  # 把处理过的模块名字放入数组
        SERVICES_EXTENSION[$SERVICES_NUM]=${extension}  # 把后缀放入数组
        PIDS_ARRAY[$SERVICES_NUM]=${pid}  # 把pid放入数组

        printf " %2d %-18s %s\n" "$SERVICES_NUM" "${name}" "$pid"    # 格式化输出
    done
}

# 等待完成
waiting_for_complete() {
    service=$1    # 获取第一个参数 服务(服务名.后缀)
    action=$2    # 获取第二个参数  操作(启动:START或者停止:STOP)

    while true; do
        pid=$(ps -ef | grep "\-jar $service$" | grep -v grep | awk '{ print $2 }')    # 获取指定服务的pid
        if [ ${action} = "START" ]; then    # 指令为启动
            if [ -z ${pid} ]; then    # 如果pid为空，即还没启动
                sleep 0.1    # 等待0.1s
            else
                return    # 启动完成，退出方法
            fi
        elif [ ${action} = "STOP" ]; then    # 指令为停止    
            if [ -z ${pid} ]; then    # 如果pid为空，即服务停止了
                return    # 停止完成，退出方法
            else    
                sleep 0.1    # 等待0.1s
            fi
        fi
    done
}

# 启动指定服务
start_service() {
    i=$1    # 取传入的第一个参数
    service=${SERVICES_ARRAY[$i]}    # 获取服务名
    extension=${SERVICES_EXTENSION[$i]}    # 获取后缀
	
	#	nohup	不挂断地运行命令，使用nohup命令后，原程序的的标准输出被自动改向到当前目录下的nohup.out文件	
	#	>	表示重定向到哪里
	#	/dev/null:表示Linux的空设备文件
	#	2:表示标准错误输出
	#	&1:&表示等同于的意思,2>&1,表示2的输出重定向等于于1
	#	&:表示后台执行,即这条指令执行在后台运行
	#	" >/dev/null 2>&1 "常用来避免shell命令或者程序等运行中有内容输出。
    nohup java ${ARGS} -jar ${service}.${extension} >/dev/null 2>&1 &    # 执行java命令
    if [ $? != 0 ]; then    # 显示最后命令的退出状态。0表示没有错误，其他任何值表明有错误。
        echo "start $service failed"
        exit 1    # 退出 退出码：非0表示失败（Non-Zero  - Failure）
    fi

    waiting_for_complete ${service}.${extension} START    #等待启动完成
}

# 停止指定服务
stop_service() {
    i=$1    # 取传入的第一个参数
    service=${SERVICES_ARRAY[$i]}    # 获取服务名
    extension=${SERVICES_EXTENSION[$i]}    # 获取后缀
    pid=${PIDS_ARRAY[$i]}    # 获取pid

    kill ${pid}    # 通过pid停止服务(进程)
    if [ $? != 0 ]; then    # 显示最后命令的退出状态。0表示没有错误，其他任何值表明有错误。
        echo "stop $service failed"
        exit 1    # 退出 退出码：非0表示失败（Non-Zero  - Failure）
    fi

    waiting_for_complete ${service}.${extension} STOP    # 等待停止完成
}

# 启动所有服务
start_all_service() {
	# 遍历数组
    for ((i=1; i<=$SERVICES_NUM; i++)); do
        pid=${PIDS_ARRAY[$i]}
        if [ -n "$pid" ]; then
            stop_service ${i}    # 先停止服务
        fi
        start_service ${i}    # 再启动服务
    done
}

# 停止所有服务
stop_all_service() {
	# 遍历数组
    for ((i=1; i<=$SERVICES_NUM; i++)); do
        pid=${PIDS_ARRAY[$i]}
        if [ -n "$pid" ]; then
            stop_service ${i}    # 停止服务
        fi
    done
}

# 选择操作
choose_service() {
	# 格式
    echo -e ${GREEN_BEGIN}"  choice [1-$SERVICES_NUM; s(start all) p(stop all)]: "${COLOR_END}"\c"
    read i    # 读取键盘输入
	
	# 特殊指令
    if [ "$i" = "q" ]; then
        exit 0    # 退出 退出码：0表示成功
    elif [ "$i" = "s" ]; then
        start_all_service    # 启动全部服务
        return
    elif [ "$i" = "p" ]; then
        stop_all_service    # 停止所有服务
        return
    fi
	
	# 选择某个服务
    echo "$i" | egrep "^[0-9]{1,}$" >/dev/null
	# 大于最大服务号或者小于1，则属于错误输入
    if [ $? -ne 0 ] || [ ${i} -gt ${SERVICES_NUM} ] || [ ${i} -lt 1 ]; then
        echo -e ${RED_BEGIN}"  choose error"${COLOR_END}    # 给出错误提示
        return    # 退出该方法
    fi

    pid=${PIDS_ARRAY[$i]}
	# pid为空时表示服务未启动
    if [ -z "$pid" ]; then # -z 检测字符串长度是否为0，为0返回 true。
        printf "The service is not running, run it? (Y/n) "    # 提示是否启动
        read c
		# 大写替换成小写
        c=$(echo ${c} | tr [A-Z] [a-z])    # tr的命令格式是tr SET1 SET2，凡是在SET1中的字符，都会被替换为SET2中相应位置上的字符
        if [ "$c" = "y" -o "$c" = "" ]; then    # -o 或运算，有一个表达式为 true 则返回 true。
            start_service ${i}    # 启动指定服务
        elif [ "$c" != "n" ]; then
            echo -e ${RED_BEGIN}"input error"${COLOR_END}
        fi
	# 服务已经启动	
    else
        printf "The service is running, stop it? (Y/n) "    # 提示是否停止
        read c
        c=$(echo ${c} | tr [A-Z] [a-z])
        if [ "$c" = "y" -o "$c" = "" ]; then
            stop_service ${i}    # 停止指定服务
        elif [ "$c" != "n" ]; then
            echo -e ${RED_BEGIN}"input error"${COLOR_END}
        fi
    fi
}

while true; do
    list_services    # 调用列表展示方法
    choose_service    # 调用选择操作方法
done
