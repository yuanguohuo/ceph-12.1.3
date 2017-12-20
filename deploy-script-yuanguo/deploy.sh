#!/bin/bash

function get_allhosts()
{
    local conf=$1

    if [ ! -s $conf ] ; then
        echo "conf file doesn't exist"
        return 1
    fi

    local tmpf=/tmp/allhosts.`date +%s`
    touch $tmpf
    echo "" > $tmpf

    local mons=""
    local osds=""
    local mdss=""
    if [ -z "$2" ] ; then #no args, get hosts for all daemons
        mons=`ceph-conf -c $conf -l mon | egrep -v '^mon$' | sort`
        osds=`ceph-conf -c $conf -l osd | egrep -v '^osd$' | sort`
        mdss=`ceph-conf -c $conf -l mds | egrep -v '^mds$' | sort`
    else
        while [ -n "$2" ] ; do
            case $2 in
                mon)
                    mons=`ceph-conf -c $conf -l mon | egrep -v '^mon$' | sort`
                    ;;
                osd)
                    osds=`ceph-conf -c $conf -l osd | egrep -v '^osd$' | sort`
                    ;;
                mds)
                    mdss=`ceph-conf -c $conf -l mds | egrep -v '^mds$' | sort`
                    ;;
                *)
                    echo "WARN: invalid arg ($2) for get_allhosts"
                    ;;
            esac
            shift
        done
    fi

    local alldaems="$mons $osds $mdss"

    for name in $mons $osds $mdss; do
        host=`ceph-conf -c $conf -n $name "host"`
        echo $host >> $tmpf
    done

    local allhosts=`sort $tmpf | uniq`
    rm -f $tmpf

    echo "$allhosts"
}

function gen_conf()
{
    local clustername=$1
    local workspace=$2

    if [ ! -d $workspace ] ; then
        echo "$workspace doesn't exist"
        return 1
    fi

    local conf=${workspace}/${clustername}.conf

    cp -f ceph.conf.template $conf
    sed -i -e "s/DUMB_CLUSTER_NAME/$clustername/" $conf

    return 0
}

function modify_systemctl()
{
    local clustername=$1
    local workspace=$2
    local user=$3

    local conf=${workspace}/${clustername}.conf

    if [ ! -s $conf ] ; then
        echo "conf file doesn't exist"
        return 1
    fi

    local sys_conf_dir=/usr/lib/systemd/system
    local mon_svc=$sys_conf_dir/ceph-mon@.service
    local osd_svc=$sys_conf_dir/ceph-osd@.service
    local mds_svc=$sys_conf_dir/ceph-mds@.service
    local mgr_svc=$sys_conf_dir/ceph-mgr@.service
    local rgw_svc=$sys_conf_dir/ceph-radosgw@.service

    if [ "X$user" == "Xroot" ] ; then
        cp -f ${mon_svc}.bak $mon_svc
        sed -i -e "s/Environment=CLUSTER=ceph/Environment=CLUSTER=$clustername/" $mon_svc
        sed -i -e 's/--setuser ceph --setgroup ceph//' $mon_svc

        cp -f ${osd_svc}.bak $osd_svc
        sed -i -e "s/Environment=CLUSTER=ceph/Environment=CLUSTER=$clustername/" $osd_svc
        sed -i -e 's/--setuser ceph --setgroup ceph//' $osd_svc

        cp -f ${mds_svc}.bak $mds_svc
        sed -i -e "s/Environment=CLUSTER=ceph/Environment=CLUSTER=$clustername/" $mds_svc
        sed -i -e 's/--setuser ceph --setgroup ceph//' $mds_svc

        cp -f ${mgr_svc}.bak $mgr_svc
        sed -i -e "s/Environment=CLUSTER=ceph/Environment=CLUSTER=$clustername/" $mgr_svc
        sed -i -e 's/--setuser ceph --setgroup ceph//' $mgr_svc

        cp -f ${rgw_svc}.bak $rgw_svc
        sed -i -e "s/Environment=CLUSTER=ceph/Environment=CLUSTER=$clustername/" $rgw_svc
        sed -i -e 's/--setuser ceph --setgroup ceph//' $rgw_svc


        for host in `get_allhosts $conf` ; do
            scp $mon_svc $osd_svc $mds_svc $mgr_svc $rgw_svc $host:$sys_conf_dir
            ssh $host "systemctl daemon-reload"
        done

    else
        #not supported yet!
        return 1
    fi

    return 0
}

function gen_keyring()
{
    local clustername=$1
    local workspace=$2

    local conf=${workspace}/${clustername}.conf

    if [ ! -s $conf ] ; then
        echo "conf file doesn't exist"
        return 1
    fi

    # 2.keyring
    local cluster_keyring=${workspace}/${clustername}.keyring
    ceph-authtool --create-keyring $cluster_keyring --gen-key -n mon. --cap mon 'allow *'

    ceph-authtool --create-keyring ${workspace}/${clustername}.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
    ceph-authtool $cluster_keyring --import-keyring ${workspace}/${clustername}.client.admin.keyring


    ceph-authtool --create-keyring ${workspace}/${clustername}.client.bootstrap-osd.keyring --gen-key -n client.bootstrap-osd --cap mon 'allow profile bootstrap-osd'
    ceph-authtool $cluster_keyring --import-keyring ${workspace}/${clustername}.client.bootstrap-osd.keyring 

    local monitors=`ceph-conf -c $conf --list-sections mon | grep "mon\."`
    for mon in $monitors ; do   #one mgr for each monitor
        local host=`echo $mon | cut -d '.' -f 2`
        ceph-authtool --create-keyring ${workspace}/${clustername}.mgr.${host}.keyring --gen-key -n mgr.${host} --cap mon 'allow profile mgr' --cap osd 'allow *' --cap mds 'allow *'
        ceph-authtool $cluster_keyring --import-keyring ${workspace}/${clustername}.mgr.${host}.keyring
    done

    return 0
}

function gen_monmap()
{
    local clustername=$1
    local workspace=$2

    local conf=${workspace}/${clustername}.conf

    if [ ! -s $conf ] ; then
        echo "conf file doesn't exist"
        return 1
    fi

    local fsid=`ceph-conf -c $conf fsid`

    local add_mons=""

    local monitors=`ceph-conf -c $conf --list-sections mon | grep "mon\."`
    for mon in $monitors ; do
        local host=`echo $mon | cut -d '.' -f 2`
        local addr=`ceph-conf -c $conf -n $mon "mon addr"`

        add_mons="$add_mons --add $host $addr"
    done

    monmaptool --create $add_mons --fsid $fsid ${workspace}/monmap

    return 0
}

function dispatch()
{
    local clustername=$1
    local workspace=$2

    local conf=${workspace}/${clustername}.conf

    if [ ! -s $conf ] ; then
        echo "conf file doesn't exist"
        return 1
    fi

    for host in `get_allhosts $conf` ; do
        scp ${workspace}/${clustername}.client.admin.keyring ${workspace}/${clustername}.client.bootstrap-osd.keyring ${workspace}/${clustername}.keyring  ${workspace}/${clustername}.conf ${workspace}/monmap $host:/etc/ceph  
    done

    return 0
}

function create_cluster()
{
    local clustername=$1
    local workspace=$2

    local conf=${workspace}/${clustername}.conf

    if [ ! -s $conf ] ; then
        echo "conf file doesn't exist"
        return 1
    fi

    local monitors=`ceph-conf -c $conf --list-sections mon | grep "mon\."`
    for mon in $monitors ; do
        local host=`echo $mon | cut -d '.' -f 2`
        local mondir=`ceph-conf -c $conf -n $mon "mon data"`

        ssh $host "rm -fr $mondir ; mkdir -p $mondir ; ceph-mon --cluster $clustername --mkfs -i $host --monmap /etc/ceph/monmap --keyring /etc/ceph/${clustername}.keyring ; touch $mondir/done"
        ssh $host "systemctl start ceph-mon@$host ; systemctl enable ceph-mon@$host ; systemctl enable ceph-mon.target"
    done

    return 0
}

function add_osds()
{
    local clustername=$1
    local workspace=$2

    local conf=${workspace}/${clustername}.conf

    if [ ! -s $conf ] ; then
        echo "conf file doesn't exist"
        return 1
    fi

    local fsid=`ceph-conf -c $conf fsid`

    local osdids=`ceph-conf -c $conf -l osd | grep "osd\." | cut -d '.' -f 2  | sort -n`

    for osdid in $osdids ; do
        local osdname=osd.${osdid}
        local host=`ceph-conf -c $conf -n $osdname "host"`
        local devs=`ceph-conf -c $conf -n $osdname "devs"`
        local data=`ceph-conf -c $conf -n $osdname "osd data"`

        ssh $host "umount -l ${devs}1 ; rm -fr $data ; parted -s $devs mklabel gpt"
        #ssh $host "ceph-disk prepare --cluster $clustername --cluster-uuid $fsid --bluestore --block.db $devs --block.wal $devs $devs"
        ssh $host "ceph-disk prepare --cluster $clustername --cluster-uuid $fsid $devs"
        ssh $host "ceph-disk activate ${devs}1 --activate-key /etc/ceph/${clustername}.client.bootstrap-osd.keyring"

        ssh $host "systemctl enable ceph-osd.target"   # !! duplicated operations, if one host has multiple osds;
    done

    return 0
}

function add_mgrs()
{
    local clustername=$1
    local workspace=$2

    local conf=${workspace}/${clustername}.conf

    if [ ! -s $conf ] ; then
        echo "conf file doesn't exist"
        return 1
    fi

    local monitors=`ceph-conf -c $conf --list-sections mon | grep "mon\."`
    for mon in $monitors ; do   #one mgr for each monitor
        local host=`echo $mon | cut -d '.' -f 2`
        local mgr=mgr.${host}
        local mgrdir=`ceph-conf -c $conf -n $mgr "mgr data"`

        ssh $host "mkdir $mgrdir"
        scp ${workspace}/${clustername}.mgr.${host}.keyring ${host}:$mgrdir/keyring
    done


    for mon in $monitors ; do   #one mgr for each monitor
        local host=`echo $mon | cut -d '.' -f 2`
        ssh $host "systemctl start ceph-mgr@${host}"
        ssh $host "systemctl enable ceph-mgr@${host}"
        ssh $host "systemctl enable ceph-mgr.target"
    done

    return 0
}

function stop_cluster()
{
    local conf=$1

    for host in `get_allhosts $conf` ; do
        local i=0
        while [ $i -lt 10 ] ; do
            ssh $host "systemctl stop ceph.target ; systemctl stop ceph-mon.target ; systemctl stop ceph-osd.target ; systemctl stop ceph-mgr.target"
            sleep 1
            local pids=`ssh $host "ps -ef | grep -v grep | grep -e '/usr/bin/ceph-mon' -e '/usr/bin/ceph-osd' -e '/usr/bin/ceph-mgr' | tr -s ' ' | cut -d ' ' -f 2"`
            if [ -z "$pids" ]  ; then
                break
            fi

            i=`expr $i + 1`
        done

        if [ $i -ge 10 ] ; then
            echo "failed stop ceph processes on $host!"
            return 1
        fi
    done

    return 0
}

function tear_down()
{
    local clustername=$1
    local conf=$2

    stop_cluster $conf
    if [ $? -ne 0 ] ; then
        return 1
    fi

    #undo add_mgrs()
    local monitors=`ceph-conf -c $conf --list-sections mon | grep "mon\."`
    for mon in $monitors ; do   #one mgr for each monitor
        local host=`echo $mon | cut -d '.' -f 2`
        local mgr=mgr.${host}
        local mgrdir=`ceph-conf -c $conf -n $mgr "mgr data"`

        ssh $host "systemctl disable ceph-mgr.target"
        ssh $host "systemctl disable ceph-mgr@${host}"

        ssh $host "rm -fr $mgrdir"
    done

    for mon in $monitors ; do   #one mgr for each monitor
        local host=`echo $mon | cut -d '.' -f 2`
        ssh $host "systemctl start ceph-mgr@${host}"
    done

    #undo add_osds()
    local osdids=`ceph-conf -c $conf -l osd | grep "osd\." | cut -d '.' -f 2  | sort -n`
    for osdid in $osdids ; do
        local osdname=osd.${osdid}
        local host=`ceph-conf -c $conf -n $osdname "host"`
        local devs=`ceph-conf -c $conf -n $osdname "devs"`
        local data=`ceph-conf -c $conf -n $osdname "osd data"`

        ssh $host "umount -l ${devs}1 ; rm -fr $data ; parted -s $devs mklabel gpt; systemctl disable ceph-osd@${osdid}"
    done

    #undo create_cluster()
    local monitors=`ceph-conf -c $conf --list-sections mon | grep "mon\."`
    for mon in $monitors ; do
        local host=`echo $mon | cut -d '.' -f 2`
        local mondir=`ceph-conf -c $conf -n $mon "mon data"`

        ssh $host "rm -fr $mondir"
    done

    #undo dispatch()
    for host in `get_allhosts $conf` ; do
        ssh $host "rm -fr /etc/ceph/${clustername}*  /etc/ceph/monmap"
    done

    #undo modify_systemctl()
    local sys_conf_dir=/usr/lib/systemd/system
    local mon_svc=$sys_conf_dir/ceph-mon@.service
    local osd_svc=$sys_conf_dir/ceph-osd@.service
    local mds_svc=$sys_conf_dir/ceph-mds@.service
    local mgr_svc=$sys_conf_dir/ceph-mgr@.service
    local rgw_svc=$sys_conf_dir/ceph-radosgw@.service
    for host in `get_allhosts $conf` ; do
        ssh $host "cp -f ${mon_svc}.bak $mon_svc ; cp -f ${osd_svc}.bak $osd_svc ; cp -f ${mds_svc}.bak $mds_svc ; cp -f ${mgr_svc}.bak $mgr_svc ; cp -f ${rgw_svc}.bak $rgw_svc" 
    done

    local log_file=`ceph-conf -c $conf "log file"`
    local log_dir=`dirname $log_file`

    for host in `get_allhosts $conf` ; do
        ssh $host "rm -fr $log_dir/* ; systemctl disable ceph.target ; systemctl disable ceph-mon.target ; systemctl disable ceph-osd.target ; systemctl disable ceph-mgr.target"
    done

    return 0
}

op=$1
cluster=testcluster
config_dir=./config

if [ "X$op" == "Xdestroy" ] ; then
    tear_down $cluster ${config_dir}/${cluster}.conf
    if [ $? -ne 0 ] ; then
        echo "destroy cluster failed"
        exit 1
    fi
elif [ "X$op" == "Xcreate" ] ; then
    rm -fr $config_dir && mkdir $config_dir

    gen_conf $cluster $config_dir

    stop_cluster ${config_dir}/${cluster}.conf
    if [ $? -ne 0 ] ; then
        echo "create cluster failed: failed to stop current cluster"
        exit 1
    fi

    modify_systemctl $cluster $config_dir root
    gen_keyring $cluster $config_dir 
    gen_monmap $cluster $config_dir 
    dispatch $cluster $config_dir 
    create_cluster $cluster $config_dir 
    add_osds $cluster $config_dir 
    add_mgrs $cluster $config_dir 
elif [ "X$op" == "Xstop" ] ; then
    stop_cluster ${config_dir}/${cluster}.conf
    if [ $? -ne 0 ] ; then
        echo "stop cluster failed"
        exit 1
    fi
fi
