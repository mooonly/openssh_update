#!/bin/bash
#返回脚本文件存放路径
script_path=$(cd `dirname $0`; pwd)
USERNAME=root   #用户名  
PASSWORD=$2     #密码  
HOST_IP=$1      #要登录的主机IP  

#设置文字颜色
Red='\e[0;31m'
Gren='\e[0;32m'
End='\033[0m'
#检查字典
declare -A check_dic


#分割线函数
function echo_leng(){
    length=$(tput cols)
    seq -s "$1" 0 $length | sed 's/[0-9]//g'
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
		check_dic+=(["$2"]="OK")
	elif [ "$3" == "NO" ] ; then
		echo -e "$str""$(seq -s "-" 0 $fgf_len | sed 's/[0-9]//g')"["$Red$3$End"]
		check_dic+=(["$2"]="NO")
	else 
		echo "ERROR" 
	fi
}

function nouseroot(){
	echo "未使用root执行，即将退出执行"
	exit -1
}

function nocentos7(){
	echo "该系统不是CetOS 7.x不符合脚本执行要求，即将退出执行"
	exit -1
}

function nobak_path(){
	echo "日志与备份目录创建失败，即将退出执行"
	exit -1
}

function rpm_install(){
	echo "该系统未安装$1软件包，即将开始安装$1软件包"
	sleep 3
	cd $script_path/tools/$1/
	rpm_pks=$(ls | tr '\n' ' ')
	rpm_list=""
	for  rpm_pk in $rpm_pks ; do 
		rpm_name=$(echo $rpm_pk | awk -F'[0-9]' '{print $1}')
		if ( rpm -qa | grep "^$rpm_name[0-9]" >>/dev/null ) ; then 
			echo "$rpm_pk 已安装"
		else
			echo "$rpm_pk 未安装"
			rpm_list="$rpm_list $rpm_pk"
		fi		
	done
	echo ">>>rpm -Uvh $rpm_list"
	rpm -Uvh $rpm_list
	wait
	rpm -Uvh *.rpm
	wait
	cd $script_path ;unset rpm_list rpm_pks
}

function paminstall(){
	echo "该系统未安装pam软件包，即将开始安装pam软件包"
        sleep 3
        echo ">>>rpm -Uvh $script_path/tools/pam/*.rpm"
        rpm -Uvh $script_path/tools/pam/pam-devel-1.1.8-22.el7.x86_64.rpm $script_path/tools/pam/pam-1.1.8-22.el7.x86_64.rpm
        wait
	pam_install=$(rpm -qa | grep -Ew "^pam|^pam-devel"|wc -l)
	if [ "$pam_install" == "2" ] ; then 
		echo "pam软件包安装成功"	
	else
		echo "pam软件包安装失败，初始化失败，即将退出脚本"
		exit -1
	fi
}

function telnetinstall(){
	rpm_install telnet
	telnet_install=$(rpm -qa | grep -Ew "^xinetd|^telnet|^telnet-server"|wc -l )
	if [ "$telnet_install" == "3" ] ; then 
		echo "telnet软件包安装成功"	
	else
		echo "telnet软件包安装失败，初始化失败，即将退出脚本"
		exit -1
	fi
	
}


function gccinstall(){
	rpm_install gcc
	gcc_install=$(rpm -qa | grep -Ew "^gcc|^cpp|^gcc-c++|^libgcc|^libgomp|^libstdc++|^libstdc++-devel"|wc -l)
	if [ "$gcc_install" == "7" ] ; then 
		echo "编译软件包安装成功"	
	else
		echo "编译软件包安装失败，初始化失败，即将退出脚本"
		exit -1
	fi
}

function zlibinstall(){
	rpm_install zlib
	zlib_install=$(rpm -qa | grep -Ew "^zlib|^zlib-devel"|wc -l)
if [ "$zlib_install" = "2" ] ;then
		echo "zlib软件包安装成功"	
	else
		echo "zlib软件包安装失败，初始化失败，即将退出脚本"
		exit -1
	fi
}

function offselinux(){
	echo "执行临时关闭SELinux策略"    #执行SELinux临时关闭
	echo ">>>setenforce 0"
	setenforce 0
	if [ $? == 0 ] ;then 
		echo "临时关闭SELinux成功"
	else
		echo "临时关闭SELinux失败，即将退出脚本"
		exit -1
	fi
}

#判断是否为root用户
sys_user=`whoami`
if [ "$sys_user" = "root" ] ;then
	echo_gsh '1、检查是否为root用户执行脚本' 'root' 'OK'
else
	echo_gsh '1、检查是否为root用户执行脚本' 'root' 'NO' 
fi

#检查系统版本
system_ver=$(awk '{print $4}' /etc/redhat-release  | cut -c 1 )
if [ "$system_ver" == "7" ] ;then 
	echo_gsh "2、检查系统版本是否符合" "system" "OK" 
else
	echo_gsh "2、检查系统版本是否符合" "system" "NO"
fi

#检查日志目录是否创建
if [ -e $script_path/BAK ] && [ -e $script_path/LOG ] ; then
	echo_gsh '3、日志与备份目录创建' 'bak_path' 'OK'
else
	echo_gsh '3、日志与备份目录创建' 'bak_path' 'NO'
fi

#检查pam软件包
pam_install=$(rpm -qa | grep -Ew "^pam|^pam-devel"|wc -l)
if [ "$pam_install" == "2" ] ; then 
	echo_gsh '4、pam软件包安装' 'pam' 'OK'
else
	echo_gsh '4、pam软件包安装' 'pam' 'NO'
fi

#检查telnet软件安装
tlnet_install=$(rpm -qa | grep -Ew "^xinetd|^telnet|^telnet-server"|wc -l )
if [ "$telnet_install" == "3" ] ; then 
	echo_gsh '5、telnet软件包安装' 'telnet' 'OK'
else
	echo_gsh '5、telnet软件包安装' 'telnet' 'NO'
fi
 
#检查编译软件安装
gcc_install=$(rpm -qa | grep -Ew "^gcc|^cpp|^gcc-c++|^libgcc|^libgomp|^libstdc++|^libstdc++-devel"|wc -l)
if [ "$gcc_install" == "7" ] ; then 
	echo_gsh '6、编译软件包安装' 'gcc' 'OK'
else
	echo_gsh '6、编译软件包安装' 'gcc' 'NO'
fi

#检查zlib是否升级
zlib_install=$(rpm -qa | grep -Ew "^zlib|^zlib-devel"|wc -l)
if [ "$zlib_install" = "2" ] ;then
	echo_gsh '7、zlib软件包安装' 'zlib' 'OK'
else
	echo_gsh '7、zlib软件包安装' 'zlib' 'NO'
fi
#检查selinux是否关闭
selinux_status=$(getenforce)
if [ "$selinux_status" = "Disabled" ] ;then
	echo_gsh '8、SElinux已关闭' 'selinux' 'OK'
else
	echo_gsh '8、SElinux已关闭' 'selinux' 'NO'
fi


echo  "初始化检查结束，开始进行初始化"
for jcx in $(echo ${!check_dic[*]})
do
	jcjg=${check_dic[$jcx]}
    if [ "$jcjg"  == "NO" ] ; then 
		case $jcx in
			"root")
				nouseroot
			;;
			"system")
				nocentos7
			;;
			"bak_path")
				nobak_path
			;;
			"pam")
				paminstall
			;;
			"telnet")
				telnetinstall
			;;
			"gcc")
				gccinstall
			;;
			"selinux")
				offselinux
			;;
			"zlib")
				zlibinstall
			;;			
		esac
	fi
done
echo "基础软件包安装成功，开始设置telnet登录"
echo "开放防火墙允许telnet访问"
#开放telnet允许访问
echo "提示：检测是否安装iptables！"
iptables_if=$(rpm -qa | grep iptables-services | wc -l)
if [ $iptables_if -eq 1 ];then
	iptables_status=$(systemctl status  iptables | grep inactive | wc -l)
	if [ $iptables_status -eq 1 ];then
		echo -e $Gren"系统已安装iptables，但未启用！"$End
		wait
		echo "提示：即将临时增加firewalld规则！"
		sleep 2
		#增加防火墙规则，开放telnet服务
		zone=$(firewall-cmd --get-active-zone | head -n 1)
		state=$(firewall-cmd --state)
		if [ "$state" = "running" ];
		then
		echo ">>>firewall-cmd --zone=$zone --add-service=telnet"
		firewall-cmd --zone=$zone --add-service=telnet
		wait
		else
		echo -e $Gren"防火墙没有开启！"$End
		fi
	else
		echo "系统已安装iptables，并且已启用！"
		echo "即将保存iptables规则！"
		sleep 3
		echo ">>>service  iptables save"
		service  iptables save
		wait
		echo "即将关闭iptables防火墙，请于升级结束测试ssh可用后再手动开启！！！"
		sleep 3
		echo ">>>systemctl stop iptables"
		systemctl stop iptables
	fi
else
	echo -e $Gren"未安装iptables！"$End
	echo "提示：即将临时增加firewalld规则！"
	sleep 3
	#增加防火墙规则，开放telnet服务
	zone=$(firewall-cmd --get-active-zone | head -n 1)
	state=$(firewall-cmd --state)
	if [ "$state" = "running" ];
	then
	echo ">>>firewall-cmd --zone=$zone --add-service=telnet"
	firewall-cmd --zone=$zone --add-service=telnet
	wait
	else
	echo -e $Gren"防火墙没有开启！"$End
	fi
fi
#开放telnet允许root登录
if [ -e /etc/securetty ] ; then 
	echo ">>>mv /etc/securetty $script_path/BAK"
	 mv /etc/securetty $script_path/BAK && echo "succ"
fi 
#重启telnet
echo ">>>systemctl  restart  xinetd"
systemctl  restart  xinetd && echo "succ"
echo ">>>systemctl  restart  telnet.socket "
systemctl  restart  telnet.socket && echo "succ"

#检查telnet监听端口
port_telnet=$(netstat -nutpl|grep LISTEN | grep ":23[^0-9]"|wc -l)
if [ "$port_telnet" == 0 ] ; then 
	echo "telnet未监听端口，telnet服务异常，即将退出脚本"
	exit -1
else
	echo "telnet服务启动成功"
fi

#测试telnet远程登录
###########执行telnet远程连接测试#########

echo "开始进行telnet 远程连接测试....."
echo "☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆"
echo "☆☆☆警告:脚本自动执行，请勿进行任何操作!☆☆☆"
echo "☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆"
sleep 2

if [ -e /tmp/who.log ] ; then 
	rm -rf /tmp/who.log
fi 
(  
    sleep 15  
    echo $USERNAME        #登录时输入用户名  
    sleep 10 
    echo $PASSWORD        #登录时输入密码  
    sleep 10
    echo "whoami  > /tmp/who.log"        #执行命令  
    sleep 2
    echo "exit"     #退出  
    sleep 2  
) | telnet $HOST_IP  #telnet到主机
sleep 5

####检查参数
who1=`cat /tmp/who.log`
#检查who1是否是空值
if [ -z $who1 ] ;then
	echo "$who1"
	echo "警告:who1是空值!telnet连接测试失败!"
	echo "已强制退出升级脚本！"
	echo "错误码:10012"
	exit
else
	echo ""
	echo "who:$who1"
fi

echo "基础环境配置完成,5秒后正式升级......"
sleep 5
#上面是基础环境配置
#下面开始正式开始升级
echo "------------------------------------------------------"
####删除解压过的文件
cd $script_path/tools
echo ">>>cd $script_path/tools"
echo ">>>rm -rf openssl-1.0.2s openssh-8.0p1"
rm -rf openssl-1.0.2s openssh-8.0p1 
wait
sleep 2

cd $script_path/tools
echo "正在后台解压文件---------------------------------------------------------"
sleep 1
echo ">>>tar -xzf openssl-1.0.2s.tar.gz"
tar -xzf openssl-1.0.2s.tar.gz
wait
sleep 1
echo ">>>tar -xzf openssh-8.0p1.tar.gz"
tar -xzf openssh-8.0p1.tar.gz
wait
echo -e $Gren"文件解压完成...."$End
echo "开始进行openssl升级......."
echo ">>>cd $script_path/tools/openssl-1.0.2s"
cd $script_path/tools/openssl-1.0.2s
echo ">>>./config shared"
./config shared
echo ">>>make && openssl_make=0 || openssl_make=1"
make && openssl_make=0 || openssl_make=1
wait
if [ "$openssl_make" == 0 ] ; then 
	echo "openssl-1.0.2s编译成功，进行安装"
	echo ">>>make install"
	make install
else
	echo "openssl-1.0.2s编译失败，即将退出本次升级！"
	exit -1
fi
if [ -e /usr/local/ssl ] ; then 
	echo "openssl-1.0.2s编译安装成功，开始卸载旧版$(openssl version)并配置ssl库"
	echo "系统已安装openssl相关软件包如下："
	rpm -qa|grep openssl
	echo "进行卸载"
	echo ">>>for i in $(rpm -qa|grep openssl);do rpm -e $i --nodeps ;done"
	for i in $(rpm -qa|grep openssl);do rpm -e $i --nodeps ;done
	echo ">>>echo "/usr/local/ssl/lib" >> /etc/ld.so.conf"
	echo "/usr/local/ssl/lib" >> /etc/ld.so.conf
	echo ">>>ldconf"
	ldconf
	echo ">>>/bin/cp  /usr/local/ssl/lib/libssl.so.1.0.0  /usr/lib64"
	/bin/cp  /usr/local/ssl/lib/libssl.so.1.0.0  /usr/lib64
	echo ">>>/bin/cp  /usr/local/ssl/lib/libcrypto.so.1.0.0  /usr/lib64"
	/bin/cp  /usr/local/ssl/lib/libcrypto.so.1.0.0  /usr/lib64
	echo ">>>ln -s /usr/lib64/libcrypto.so.1.0.0  /usr/lib64/libcrypto.so.10"
	ln -s /usr/lib64/libcrypto.so.1.0.0  /usr/lib64/libcrypto.so.10
	echo ">>>ln -s /usr/lib64/libcrypto.so.1.0.0  /usr/lib64/libcrypto.so"
	ln -s /usr/lib64/libcrypto.so.1.0.0  /usr/lib64/libcrypto.so
	echo ">>>ln -s /usr/lib64/libssl.so.1.0.0  /usr/lib64/libssl.so.10"
	ln -s /usr/lib64/libssl.so.1.0.0  /usr/lib64/libssl.so.10
	echo ">>>ln -s /usr/lib64/libssl.so.1.0.0  /usr/lib64/libssl.so"
	ln -s /usr/lib64/libssl.so.1.0.0  /usr/lib64/libssl.so
	echo ">>>ln -s /usr/local/ssl/bin/openssl  /usr/bin/openssl"
	ln -s /usr/local/ssl/bin/openssl  /usr/bin/openssl
	echo ">>>ln -s /usr/local/ssl/include/openssl   /usr/include/openssl"
	ln -s /usr/local/ssl/include/openssl   /usr/include/openssl
	echo "openssl-1.0.2s配置完成"
else
	echo "openssl-1.0.2s编译安装失败，即将退出本次升级！"
	exit -1 
fi

#检查openssl版本
if openssl version |grep "1.0.2s" ; then 
	echo "openssl-1.0.2s升级成功！！"
else
	echo "openssl-1.0.2s升级失败！！即将退出本次升级！！"
	exit -1
fi 
sleep 5
echo ''
echo ''
echo "开始进行openssh升级......."
echo ">>>cd $script_path/tools/openssh-8.0p1"
cd $script_path/tools/openssh-8.0p1
echo ">>>./configure --prefix=/usr --sysconfdir=/etc/ssh --with-md5-passwords--with-pam --with-tcp-wrappers --with-ssl-dir=/usr/local/ssl --without-hardening"
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-md5-passwords--with-pam --with-tcp-wrappers --with-ssl-dir=/usr/local/ssl --without-hardening
echo ">>>make && openssh_make=0 || openssh_make=1"
make && openssh_make=0 || openssh_make=1
wait
if [ "$openssh_make" == 0 ] ; then 
	echo "openssh-8.0p1编译成功，开始卸载旧版本$(ssh -V 2>&1| awk -F',' '{print $1}' 2>/dev/null)安装新版本"
	echo "备份ssh配置文件"
	cp /etc/ssh/sshd_config   $script_path/BAK/
	echo "系统已安装openssh相关软件包如下："
	rpm -qa |grep openssh
	echo "进行卸载"
	echo ">>>for i in $(rpm -qa |grep openssh);do rpm -e $i --nodeps ;done"
	for i in $(rpm -qa |grep openssh);do rpm -e $i --nodeps ;done 
	echo ">>>mv /etc/ssh $script_path/BAK/ssh_old"
	mv /etc/ssh $script_path/BAK/ssh_old || rm -rf /etc/ssh && echo 'succ'
    echo ">>>cp /root/.ssh $script_path/BAK/bak.ssh"
	cp /root/.ssh $script_path/BAK/bak.ssh && echo 'succ'
	echo ">>>make install"
	make install
else
	echo "openssh-8.0p1编译失败，即将退出本次升级！"
	exit -1
fi

#检查openssh版本
if ssh -V 2>&1| awk -F',' '{print $1}'| grep "8.0p1" ; then 
	echo "openssh-8.0p1升级成功！！"
else
	echo "openssh-8.0p1升级失败！！即将退出本次升级！！"
	exit -1
fi 

echo "开始配置ssh服务"
echo ">>>cd $script_path/tools/openssh-8.0p1"
cd $script_path/tools/openssh-8.0p1 && echo 'succ'
echo ">>>cp ./contrib/redhat/sshd.init /etc/init.d/sshd"
cp ./contrib/redhat/sshd.init /etc/init.d/sshd && echo 'succ'
echo ">>>chkconfig --add sshd"
chkconfig --add sshd && echo 'succ'
echo ">>>chkconfig sshd on"
chkconfig sshd on && echo 'succ'
echo ">>>chkconfig --list|grep sshd"
chkconfig --list|grep sshd 
echo ">>>/bin/cp -rf $script_path/bak/sshd_config /etc/ssh/sshd_config"
/bin/cp -rf $script_path/BAK/sshd_config /etc/ssh/sshd_config && echo 'succ'

echo ">>>"
if [ ! -e /etc/pam.d/sshd ] ; then 
	echo ">>>cp $script_path/tools/sshd  /etc/pam.d/sshd"
	yes|cp $script_path/tools/sshd  /etc/pam.d/sshd && echo 'succ'

fi
echo ">>>sed -i 's/\#PermitRootLogin .*/PermitRootLogin yes/g' /etc/ssh/sshd_config"
sed -i 's/\#PermitRootLogin .*/PermitRootLogin yes/g' /etc/ssh/sshd_config && echo 'succ'
echo ">>>sed -i 's/\/usr\/libexec\/sftp-server/\/usr\/local\/openssh\/libexec\/sftp-server/g' /etc/ssh/sshd_config"
sed -i 's/\/usr\/libexec\/sftp-server/\/usr\/local\/openssh\/libexec\/sftp-server/g' /etc/ssh/sshd_config && echo 'succ'
echo ">>>sed -i 's/\#UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config"
sed -i 's/\#UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config && echo 'succ'
echo ">>>sed -i 's/\GSSAPICleanupCredentials.*/GSSAPICleanupCredentials no/g' /etc/ssh/sshd_config"
sed -i 's/\GSSAPICleanupCredentials.*/GSSAPICleanupCredentials no/g' /etc/ssh/sshd_config && echo 'succ'
echo ">>>sed -i 's/\#X11Forwarding.*/X11Forwarding yes/g' /etc/ssh/sshd_config"
sed -i 's/\#X11Forwarding.*/X11Forwarding yes/g' /etc/ssh/sshd_config && echo 'succ'
echo ">>>cp $script_path/sshd.service /usr/lib/systemd/system/" 
yes|cp $script_path/tools/sshd.service /usr/lib/systemd/system/ && echo 'succ'
echo "配置完成"
echo -e "正在启动sshd服务..."
echo ">>>>> >>>> >>> >> >"
echo ">>>systemctl restart sshd"
systemctl restart sshd  
service  sshd restart
wait
sleep 5
echo ">>>echo '' > /root/.ssh/known_hosts"
echo '' > /root/.ssh/known_hosts && echo 'succ'
Result="$(sshpass -p "$PASSWORD" ssh -v -o StrictHostKeyChecking=no root@$HOST_IP "whoami" 2>&1)"
ssh_version=$(echo $Result| grep -owi "remote software version openssh_..."  | awk '{print $NF}')
who_am_i="$(sshpass -p "$PASSWORD" ssh  -o StrictHostKeyChecking=no root@$HOST_IP "whoami" 2>/dev/null)"
echo $ssh_version  $who_am_i

if [ "$ssh_version" == 'OpenSSH_8.0' ] && [ "$who_am_i" == 'root' ]; then 
          echo "openssh升级完成！！！！！！"
elif [ "$ssh_version" == 'OpenSSH_8.0' ]  ; then 
        echo "openssh服务启动成功单连接测试失败，请手动进行连接测试，如有问题请通过telnet登录进行排查！！！"
else
        echo "openssh升级失败，请通过telnet登录进行手动升级！！！"
fi

echo_jz   "------按ctrl+C退出-------"
