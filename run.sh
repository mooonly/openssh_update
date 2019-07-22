#!/bin/bash
#返回脚本文件存放路径
script_path=$(cd `dirname $0`; pwd)
host_ip=$1
password=$2

#格式化输出函数
function echo_gsh(){
	length=$(tput cols)
	str="$1"
	str_len="$(echo $1 |wc -L)"
	let echo_len=$str_len+4
	let echo_line=$echo_len/$length
	if [ "$echo_line" != "0" ]; then
		let fgf_len=$length*$echo_line-$echo_len
	else
		let fgf_len=$length-$echo_len
	fi
	if [ "$3" == "OK" ] ; then
		echo -e "$str""$(seq -s "-" 0 $fgf_len | sed 's/[0-9]//g')"["$Green$3$End"]
	elif [ "$3" == "NO" ] ; then
		echo -e "$str""$(seq -s "-" 0 $fgf_len | sed 's/[0-9]//g')"["$Red$3$End"]
	else 
		echo "ERROR" 
	fi
}
#居中显示
function echo_jz(){
    str="$*"
    leng_th="$(tput cols)"
    str_len=$(echo "$str" | wc -L)
    if [ "$str_len" -lt "$leng_th" ] ; then 
	lens=$((str_len/leng_th)) 
	length=$((leng_th*lens))		
	jz_len=$(((leng_th-str_len)/2))
	echo -e "\e[$[jz_len]C""$str" 
    else
	jz_len=$(((leng_th-str_len)/2))
	echo -e "\e[$[jz_len]C""$str" 
    fi	
}

echo_jz '              __                    __      __     '
echo_jz '   __________/ /_  __  ______  ____/ /___ _/ /____ '
echo_jz '  / ___/ ___/ __ \/ / / / __ \/ __  / __ `/ __/ _ \'
echo_jz ' (__  |__  ) / / / /_/ / /_/ / /_/ / /_/ / /_/  __/'
echo_jz '/____/____/_/ /_/\__,_/ .___/\__,_/\__,_/\__/\___/ '
echo_jz '                     /_/                           '

#创建备份与日志目录
[ -e $script_path/BAK ]  && (mv $script_path/BAK $script_path/BAK_$(date +%F_%H%M%S);mkdir $script_path/BAK)||mkdir $script_path/BAK
[ -e $script_path/LOG ] &&  (mv $script_path/LOG $script_path/LOG_$(date +%F_%H%M%S);mkdir $script_path/LOG) || mkdir $script_path/LOG

echo_jz "openssh升级时，需先要开启telnet，确保telnet可以正常登陆。"
echo_jz "这样当openssh升级出现问题的时候，还可以通过telnet登录到服务器操作。"
echo_jz "此脚本需要您提供root账户的密码来自动进行telnet连接测试"
echo_jz "可通过执行./run.sh host   password 的方式直接带入密码"
echo_jz "eg:./run.sh 192.168.1.1  123456"
echo_jz "或者直接执行./run.sh 来进行交互式获取"
echo '' 
sleep 3
#检查ssh和ssl版本是否需要升级
if (ssh -V 2>&1 | grep "OpenSSH_8.0p1" > /dev/null) ; then 
	echo "此系统的ssh版本为$(ssh -V 2>&1)"
	echo "无需升级，即将退出脚本"
	exit -1 
fi
#检查sshpass是否安装
sshpass_install=$(rpm -qa | grep -w "^sshpass"|wc -l )
if [ "$sshpass_install" == "1" ] ; then 
	echo_gsh 'sshpass软件包安装' 'sshpass' 'OK'
else
	echo "安装sshpass，用来测试密码是否正确"
	echo ">>>rpm -ivh $script_path/tools/sshpass/sshpass-1.06-2.el7.x86_64.rpm"
	rpm -ivh $script_path/tools/sshpass/sshpass-1.06-2.el7.x86_64.rpm
	sshpass_install=$(rpm -qa | grep -w "^sshpass"|wc -l )
	if [ "$sshpass_install" == "1" ] ; then 
		echo_gsh 'sshpass软件包安装' 'sshpass' 'OK'
	else
		echo_gsh 'sshpass软件包安装' 'sshpass' 'NO'
		echo 'sshpass软件包安装失败，即将退出脚本'
		exit -1
	fi
fi

#获取服务器ip
#判断本服务器系统是否有多个ip
ips=$(hostname -I | awk '{print NF}')
if [ $ips -eq 1 ] ; then
#判断，如果系统只有一个ip，那么，取这个ip
	ip=$(hostname -I )
elif [  $host_ip ] ;then
	local_ip=$(hostname -I |tr ' ' '\n' |grep "$host_ip"|wc -l)
	if [ $local_ip -ne 1 ] ;then
		echo "咱能不开玩笑么？？？"
		echo "本服务器不存在您输入的ip，即将退出脚本！"
		exit -1
	else
		echo "指定本机IP为$host_ip"
		ip=$host_ip
	fi
else
#自动判断登录ip,如果失败则让用户手动选择ip
	echo "！！！本服务器存在多个ip！！！"
	echo "当前服务器ip如下:"
	ip_count=$(hostname -I )
	echo "$ip_count" | tr ' ' '\n'
	echo "开始自动选择ip"
	SRT_ip=$(who am i  | awk -F "['(']|[')']" '{print $2}')
	DET_ip=$(lsof -i:22  | grep 'ESTABLISHED'|grep "$SRT_ip"   | awk '{print $9}' |awk -F ':' '{print $1}' |head -n 1 )
#判断自动选择ip是否包含在地址池内
	ip=${DET_ip%:*}
	local_ip=$(hostname -I |tr ' ' '\n' |grep "$ip"|wc -l)
	#自动获取失败，手动输入
	if [ $local_ip -ne 1 ] ;
	then
		echo "自动选择IP失败，请手动输入本服务器IP"
		while true
		do
			read -p "请输入本服务器IP: " ip
			local_ip=$(hostname -I |tr ' ' '\n' |grep "$ip"|wc -l)
			if [ $local_ip -ne 1 ] ;then
				echo "咱能不开玩笑么？？？"
				echo "本服务器不存在您输入的ip，请重新输入！"
			else
				break
			fi
		done
	else
		echo -e "自动选择ip成功，当前选定ip为$ip"
		sleep 2
	fi
fi

sleep 1
#获取root密码


while true
do
	if [  $password ] ; then 
		root_passwd=$password
	else
		read -p "请输入root密码：" root_passwd
		wait
	fi
	Result="$(sshpass -p "$root_passwd" ssh -o StrictHostKeyChecking=no root@$ip "whami" 2>&1)"
	if  echo "$Result"|grep -qi 'No route to host';then
		echo -e "Error: [$ip] No route to host"  >&2
		echo -e "错误码:20005"
		exit 1
	elif  echo "$Result"|grep -qi 'Permission denied';then
		echo "当前输入的密码不正确: $root_passwd " >&2
		echo  "请重新输入root密码！"	
		unset password
	else  echo "$Result"|grep -qi 'root'
		break
	fi
done
nohup  bash $script_path/ssh_update_noyum.sh $ip $root_passwd | tee -a -- $script_path/LOG/log.$(date +%F_%H%M%S)
