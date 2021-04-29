#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

GNS_IP=${gns_ip}

GI_HOME=$(cat /etc/oracle/olr.loc 2>/dev/null | grep crs_home | awk -F= '{print $2}')
GI_VERSION=$($GI_HOME/bin/oraversion -compositeVersion)

$GI_HOME/bin/asmcmd setattr -G DATA compatible.asm $GI_VERSION

$GI_HOME/bin/srvctl add gns -vip $GNS_IP
$GI_HOME/bin/srvctl start gns

#$GI_HOME/bin/srvctl add havip -id rhphavip -address $HA_VIP

$GI_HOME/bin/srvctl stop rhpserver
$GI_HOME/bin/srvctl remove rhpserver

$GI_HOME/bin/srvctl add rhpserver -storage /rhp_storage -diskgroup DATA
$GI_HOME/bin/srvctl start rhpserver

sudo -u grid $GI_HOME/bin/srvctl modify rhpserver -pl_port 8900
sudo -u grid $GI_HOME/bin/srvctl modify rhpserver -port_range 8901-8906
