#!/usr/bin/bash

function uninstall_fio()
{
    rpm -e fio-2.2.8-2.el7.x86_64
}

function uninstall_ceph_10_2_3()
{
    rpm -e librados2-devel-10.2.3-0.el7.centos.x86_64
    rpm -e ceph-radosgw-10.2.3-0.el7.centos.x86_64
    rpm -e ceph-10.2.3-0.el7.centos.x86_64
    rpm -e ceph-mds-10.2.3-0.el7.centos.x86_64
    rpm -e ceph-mon-10.2.3-0.el7.centos.x86_64
    rpm -e ceph-osd-10.2.3-0.el7.centos.x86_64
    rpm -e ceph-selinux-10.2.3-0.el7.centos.x86_64 ceph-base-10.2.3-0.el7.centos.x86_64
    rpm -e ceph-common-10.2.3-0.el7.centos.x86_64
    rpm -e libradosstriper1-10.2.3-0.el7.centos.x86_64
    rpm -e librgw2-10.2.3-0.el7.centos.x86_64
    rpm -e python-cephfs-10.2.3-0.el7.centos.x86_64
    rpm -e libcephfs1-10.2.3-0.el7.centos.x86_64
    rpm -e python-rbd-10.2.3-0.el7.centos.x86_64
    rpm -e librbd1-10.2.3-0.el7.centos.x86_64
    rpm -e python-rados-10.2.3-0.el7.centos.x86_64
    rpm -e librados2-10.2.3-0.el7.centos.x86_64
}

function uninstall_ceph_12_1_3()
{
    rpm -e ceph-radosgw-12.1.3-0.el7.centos.x86_64
    rpm -e ceph-12.1.3-0.el7.centos.x86_64
    rpm -e ceph-mgr-12.1.3-0.el7.centos.x86_64
    rpm -e ceph-mds-12.1.3-0.el7.centos.x86_64
    rpm -e ceph-mon-12.1.3-0.el7.centos.x86_64
    rpm -e ceph-osd-12.1.3-0.el7.centos.x86_64
    rpm -e ceph-selinux-12.1.3-0.el7.centos.x86_64 ceph-base-12.1.3-0.el7.centos.x86_64
    rpm -e ceph-common-12.1.3-0.el7.centos.x86_64
    rpm -e python-rgw-12.1.3-0.el7.centos.x86_64
    rpm -e libradosstriper-devel-12.1.3-0.el7.centos.x86_64
    rpm -e libradosstriper1-12.1.3-0.el7.centos.x86_64
    rpm -e librados-devel-12.1.3-0.el7.centos.x86_64
    rpm -e librgw2-12.1.3-0.el7.centos.x86_64
    rpm -e python-cephfs-12.1.3-0.el7.centos.x86_64
    rpm -e libcephfs2-12.1.3-0.el7.centos.x86_64
    rpm -e python-rbd-12.1.3-0.el7.centos.x86_64
    rpm -e librbd1-12.1.3-0.el7.centos.x86_64
    rpm -e python-rados-12.1.3-0.el7.centos.x86_64
    rpm -e librados2-12.1.3-0.el7.centos.x86_64
}

function uninstall_ceph_0_8_7()
{
    yum remove librados2-1:0.80.7-3.el7.x86_64 -y
}

function install_deps()
{
    yum -y install boost-devel.x86_64
    yum -y install lttng-ust-devel.x86_64
    yum -y install hdparm.x86_64
    yum -y install gdisk.x86_64
    yum -y install redhat-lsb-core.x86_64
    yum -y install python-requests.noarch
    yum -y install python-setuptools.noarch
    yum -y install fcgi-devel.x86_64
    yum -y install libbabeltrace-devel.x86_64
    yum -y install gperftools-libs.x86_64
    yum -y install selinux-policy.noarch
    yum -y install leveldb.x86_64
    yum -y install fuse-devel.x86_64
    yum -y install python-flask.noarch
    yum -y install mailcap.noarch
    yum -y install jemalloc.x86_64 jemalloc-devel.x86_64
    yum -y install libibverbs.x86_64
    yum -y install python-prettytable.noarch
    yum -y install pyOpenSSL.x86_64  python-cherrypy.noarch  python-pecan.noarch
}

function install_ceph_12_1_3()
{
    rpm -hiv librados2-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv python-rados-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv librbd1-12.1.3-0.el7.centos.x86_64.rpm
    rpm -hiv python-rbd-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv libcephfs2-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv python-cephfs-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv librgw2-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv librados-devel-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv libradosstriper1-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv libradosstriper-devel-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv python-rgw-12.1.3-0.el7.centos.x86_64.rpm
    rpm -hiv ceph-common-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv ceph-selinux-12.1.3-0.el7.centos.x86_64.rpm ceph-base-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv ceph-osd-12.1.3-0.el7.centos.x86_64.rpm 
    rpm -hiv ceph-mon-12.1.3-0.el7.centos.x86_64.rpm
    rpm -hiv ceph-mds-12.1.3-0.el7.centos.x86_64.rpm
    rpm -hiv ceph-mgr-12.1.3-0.el7.centos.x86_64.rpm
    rpm -hiv ceph-12.1.3-0.el7.centos.x86_64.rpm
    rpm -hiv ceph-radosgw-12.1.3-0.el7.centos.x86_64.rpm 
}


function usage()
{
    echo "Usage: ./install.yuanguo.sh"
    echo "               install deps | ceph12 | all"
    echo "               uninstall  ceph12 | all"
}


op=$1
what=$2

if [ "X$op" == "Xinstall" ] ; then
    if [ "X$what" == "Xdeps" ] ; then
        install_deps
    elif [ "X$what" == "Xceph12" ] ; then
        install_ceph_12_1_3
    elif [ "X$what" == "Xall" ] ; then
        install_deps
        install_ceph_12_1_3
    else
        echo "Error: invalid parameter for install"
        usage
        exit 1
    fi
elif [ "X$op" == "Xuninstall" ] ; then
    if [ "X$what" == "Xall" ] ; then
        uninstall_fio
        uninstall_ceph_0_8_7
        uninstall_ceph_10_2_3
        uninstall_ceph_12_1_3
    elif [ "X$what" == "Xceph12" ] ; then
        uninstall_ceph_12_1_3
    else
        echo "Error: invalid parameter for uninstall"
        usage
        exit 1
    fi
else
    echo "Error: invalid op"
    usage
    exit 1
fi
