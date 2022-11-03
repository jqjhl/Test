#!/bin/bash

#写入hosts路由配置
tee /etc/hosts <<-'EOF'
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.100.100 master
192.168.100.101 slave1
192.168.100.102 slave2
EOF

#删除旧配置
rm -rf /opt/software/*
rm -rf /usr/local/hadoop/*
rm -rf /usr/local/java/*
rm -rf /usr/lib/jvm/*
rm -rf ~/.ssh/*
rm -rf /home/27liusaiqi/.ssh/*
ssh slave1 "rm -rf /opt/software/*; rm -rf /usr/local/hadoop/*; rm -rf /usr/local/java/*; rm -rf /usr/lib/jvm/*; rm -rf ~/.ssh/*; rm -rf /home/27liusaiqi/.ssh/*"
ssh slave2 "rm -rf /opt/software/*; rm -rf /usr/local/hadoop/*; rm -rf /usr/local/java/*; rm -rf /usr/lib/jvm/*; rm -rf ~/.ssh/*; rm -rf /home/27liusaiqi/.ssh/*"

#配置root用户免密
ssh-keygen -t rsa
ssh-copy-id -i ~/.ssh/id_rsa.pub root@master
ssh-copy-id -i ~/.ssh/id_rsa.pub root@slave1
ssh-copy-id -i ~/.ssh/id_rsa.pub root@slave2

#配置普通用户免密
sudo -u 27liusaiqi ssh-keygen -t rsa
sudo -u 27liusaiqi ssh-copy-id -i /home/27liusaiqi/.ssh/id_rsa.pub 27liusaiqi@master
sudo -u 27liusaiqi ssh-copy-id -i /home/27liusaiqi/.ssh/id_rsa.pub 27liusaiqi@slave1
sudo -u 27liusaiqi ssh-copy-id -i /home/27liusaiqi/.ssh/id_rsa.pub 27liusaiqi@slave2

#关闭防火墙
systemctl stop firewalld.service
systemctl disable firewalld.service
ssh slave1 "systemctl stop firewalld.service; systemctl disable firewalld.service"
ssh slave2 "systemctl stop firewalld.service; systemctl disable firewalld.service"

#安装jdk
#镜像 https://repo.huaweicloud.com/apache/hadoop/
mkdir -p /usr/local/java
wget -P /usr/local/java https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz
tar -zxvf /usr/local/java/jdk-8u202-linux-x64.tar.gz -C /usr/local/java
rm -rf /usr/local/java/jdk-8u202-linux-x64.tar.gz

#安装hadoop
#镜像 https://repo.huaweicloud.com/java/jdk/
mkdir -p /opt/software
wget -P /opt/software https://repo.huaweicloud.com/apache/hadoop/common/hadoop-2.7.7/hadoop-2.7.7.tar.gz
tar -zxvf /opt/software/hadoop-2.7.7.tar.gz -C /opt/software
rm -rf /opt/software/hadoop-2.7.7.tar.gz

#写入环境变量
tee /etc/profile <<-'EOF'
# /etc/profile

# System wide environment and startup programs, for login setup
# Functions and aliases go in /etc/bashrc

# It's NOT a good idea to change this file unless you know what you
# are doing. It's much better to create a custom.sh shell script in
# /etc/profile.d/ to make custom changes to your environment, as this
# will prevent the need for merging in future updates.

pathmunge () {
    case ":${PATH}:" in
        *:"$1":*)
            ;;
        *)
            if [ "$2" = "after" ] ; then
                PATH=$PATH:$1
            else
                PATH=$1:$PATH
            fi
    esac
}


if [ -x /usr/bin/id ]; then
    if [ -z "$EUID" ]; then
        # ksh workaround
        EUID=`/usr/bin/id -u`
        UID=`/usr/bin/id -ru`
    fi
    USER="`/usr/bin/id -un`"
    LOGNAME=$USER
    MAIL="/var/spool/mail/$USER"
fi

# Path manipulation
if [ "$EUID" = "0" ]; then
    pathmunge /usr/sbin
    pathmunge /usr/local/sbin
else
    pathmunge /usr/local/sbin after
    pathmunge /usr/sbin after
fi

HOSTNAME=`/usr/bin/hostname 2>/dev/null`
HISTSIZE=1000
if [ "$HISTCONTROL" = "ignorespace" ] ; then
    export HISTCONTROL=ignoreboth
else
    export HISTCONTROL=ignoredups
fi

export PATH USER LOGNAME MAIL HOSTNAME HISTSIZE HISTCONTROL

# By default, we want umask to get set. This sets it for login shell
# Current threshold for system reserved uid/gids is 200
# You could check uidgid reservation validity in
# /usr/share/doc/setup-*/uidgid file
if [ $UID -gt 199 ] && [ "`/usr/bin/id -gn`" = "`/usr/bin/id -un`" ]; then
    umask 002
else
    umask 022
fi

for i in /etc/profile.d/*.sh /etc/profile.d/sh.local ; do
    if [ -r "$i" ]; then
        if [ "${-#*i}" != "$-" ]; then 
            . "$i"
        else
            . "$i" >/dev/null
        fi
    fi
done

unset i
unset -f pathmunge



#Java
export JAVA_HOME=/usr/local/java/jdk1.8.0_202
export JRE_HOME=$JAVA_HOME/jre
export CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib
export PATH=$JAVA_HOME/bin:$PATH



#Hadoop
export HADOOP_HOME=/opt/software/hadoop-2.7.7
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
EOF
source /etc/profile

#写入hadoop-env.sh文件配置
tee /opt/software/hadoop-2.7.7/etc/hadoop/hadoop-env.sh <<-'EOF'
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set Hadoop-specific environment variables here.

# The only required environment variable is JAVA_HOME.  All others are
# optional.  When running a distributed configuration it is best to
# set JAVA_HOME in this file, so that it is correctly defined on
# remote nodes.

# The java implementation to use.
export JAVA_HOME=/usr/local/java/jdk1.8.0_202

# The jsvc implementation to use. Jsvc is required to run secure datanodes
# that bind to privileged ports to provide authentication of data transfer
# protocol.  Jsvc is not required if SASL is configured for authentication of
# data transfer protocol using non-privileged ports.
#export JSVC_HOME=${JSVC_HOME}

export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-"/etc/hadoop"}

# Extra Java CLASSPATH elements.  Automatically insert capacity-scheduler.
for f in $HADOOP_HOME/contrib/capacity-scheduler/*.jar; do
  if [ "$HADOOP_CLASSPATH" ]; then
    export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$f
  else
    export HADOOP_CLASSPATH=$f
  fi
done

# The maximum amount of heap to use, in MB. Default is 1000.
#export HADOOP_HEAPSIZE=
#export HADOOP_NAMENODE_INIT_HEAPSIZE=""

# Extra Java runtime options.  Empty by default.
export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true"

# Command specific options appended to HADOOP_OPTS when specified
export HADOOP_NAMENODE_OPTS="-Dhadoop.security.logger=${HADOOP_SECURITY_LOGGER:-INFO,RFAS} -Dhdfs.audit.logger=${HDFS_AUDIT_LOGGER:-INFO,NullAppender} $HADOOP_NAMENODE_OPTS"
export HADOOP_DATANODE_OPTS="-Dhadoop.security.logger=ERROR,RFAS $HADOOP_DATANODE_OPTS"

export HADOOP_SECONDARYNAMENODE_OPTS="-Dhadoop.security.logger=${HADOOP_SECURITY_LOGGER:-INFO,RFAS} -Dhdfs.audit.logger=${HDFS_AUDIT_LOGGER:-INFO,NullAppender} $HADOOP_SECONDARYNAMENODE_OPTS"

export HADOOP_NFS3_OPTS="$HADOOP_NFS3_OPTS"
export HADOOP_PORTMAP_OPTS="-Xmx512m $HADOOP_PORTMAP_OPTS"

# The following applies to multiple commands (fs, dfs, fsck, distcp etc)
export HADOOP_CLIENT_OPTS="-Xmx512m $HADOOP_CLIENT_OPTS"
#HADOOP_JAVA_PLATFORM_OPTS="-XX:-UsePerfData $HADOOP_JAVA_PLATFORM_OPTS"

# On secure datanodes, user to run the datanode as after dropping privileges.
# This **MUST** be uncommented to enable secure HDFS if using privileged ports
# to provide authentication of data transfer protocol.  This **MUST NOT** be
# defined if SASL is configured for authentication of data transfer protocol
# using non-privileged ports.
export HADOOP_SECURE_DN_USER=${HADOOP_SECURE_DN_USER}

# Where log files are stored.  $HADOOP_HOME/logs by default.
#export HADOOP_LOG_DIR=${HADOOP_LOG_DIR}/$USER

# Where log files are stored in the secure data environment.
export HADOOP_SECURE_DN_LOG_DIR=${HADOOP_LOG_DIR}/${HADOOP_HDFS_USER}

###
# HDFS Mover specific parameters
###
# Specify the JVM options to be used when starting the HDFS Mover.
# These options will be appended to the options specified as HADOOP_OPTS
# and therefore may override any similar flags set in HADOOP_OPTS
#
# export HADOOP_MOVER_OPTS=""

###
# Advanced Users Only!
###

# The directory where pid files are stored. /tmp by default.
# NOTE: this should be set to a directory that can only be written to by 
#       the user that will run the hadoop daemons.  Otherwise there is the
#       potential for a symlink attack.
export HADOOP_PID_DIR=${HADOOP_PID_DIR}
export HADOOP_SECURE_DN_PID_DIR=${HADOOP_PID_DIR}

# A string representing this instance of hadoop. $USER by default.
export HADOOP_IDENT_STRING=$USER
EOF

#写入core-site.xml文件配置
tee /opt/software/hadoop-2.7.7/etc/hadoop/core-site.xml <<-'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://master:9000</value>
    </property>

    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/software/hadoop-2.7.7/tmp</value>
    </property>
</configuration>
EOF

#写入hdfs-site.xml.sh文件配置
tee /opt/software/hadoop-2.7.7/etc/hadoop/hdfs-site.xml <<-'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>/opt/software/hadoop-2.7.7/data/name</value>
    </property>

    <property>
        <name>dfs.namenode.http-address</name>
        <value>master:50070</value>
    </property>
    
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/opt/software/hadoop-2.7.7/data/data</value>
    </property>

    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
    
	  <property>
		    <name>dfs.permissions</name>
		    <value>false</value>
	  </property>

    <property>
        <name>dfs.webhdfs.enabled</name>
        <value>true</value>
    </property>
</configuration>

EOF

#写入yarn-site.xml.sh文件配置
tee /opt/software/hadoop-2.7.7/etc/hadoop/yarn-site.xml <<-'EOF'
<?xml version="1.0"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Site specific YARN configuration properties -->

<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>master</value>
    </property>

    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>

    <property>
        <name>yarn.resourcemanager.webapp.address</name>
        <value>master:8088</value>
    </property>
</configuration>
EOF

#写入mapred-site文件配置
tee /opt/software/hadoop-2.7.7/etc/hadoop/mapred-site.xml <<-'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
       Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>
EOF

#写入slaves文件配置
tee /opt/software/hadoop-2.7.7/etc/hadoop/slaves <<-'EOF'
master
slave1
slave2
EOF

#创建hadoop储存目录
mkdir -p /opt/software/hadoop-2.7.7/tmp
mkdir -p /opt/software/hadoop-2.7.7/data/name
mkdir -p /opt/software/hadoop-2.7.7/data/data

#分发配置文件
scp /etc/hosts root@slave1:/etc/hosts
scp /etc/hosts root@slave2:/etc/hosts
scp -r /usr/local/java/jdk1.8.0_202 root@slave1:/usr/local/java/jdk1.8.0_202
scp -r /usr/local/java/jdk1.8.0_202 root@slave2:/usr/local/java/
scp -r /opt/software/hadoop-2.7.7 root@slave1:/opt/software/
scp -r /opt/software/hadoop-2.7.7 root@slave2:/opt/software/
scp /etc/profile root@slave1:/etc/profile
scp /etc/profile root@slave2:/etc/profile
scp /home/27liusaiqi/.bash_profile root@slave1:/home/27liusaiqi/.bash_profile
scp /home/27liusaiqi/.bash_profile root@slave2:/home/27liusaiqi/.bash_profile

#改software文件权限
chown -R 27liusaiqi /opt/software
ssh slave1 "chown -R 27liusaiqi /opt/software"
ssh slave2 "chown -R 27liusaiqi /opt/software"

# #修改主机名
# hostnamectl set-hostname master

# #写入ifcfg-ens33网卡配置
# tee /etc/sysconfig/network-scripts/ifcfg-ens33 <<-'EOF'
# TYPE="Ethernet"
# PROXY_METHOD="none"
# BROWSER_ONLY="no"
# BOOTPROTO="static"
# DEFROUTE="yes"
# IPV4_FAILURE_FATAL="no"
# IPV6INIT="yes"
# IPV6_AUTOCONF="yes"
# IPV6_DEFROUTE="yes"
# IPV6_FAILURE_FATAL="no"
# IPV6_ADDR_GEN_MODE="stable-privacy"
# NAME="ens33"
# UUID="f7f94a83-190c-4f57-b902-5a640d0c5fc1"
# DEVICE="ens33"
# ONBOOT="yes"
# IPADDR="192.168.100.100"
# NETMASK="255.255.255.0"
# GATEWAY="192.168.100.2"
# DNS1="114.114.114.114"
# EOF

# #格式化hadoop
# su 27liusaiqi -c "hdfs namenode -format"

# #启动hadoop
# su 27liusaiqi -c "start-all.sh"