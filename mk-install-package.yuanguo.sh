

DIR=../../ceph-12.1.3-package
TAR=${DIR}.tar.gz

rm -fr $DIR $TAR
mkdir $DIR

cp -f                                                                        \
      ../../RPMS/x86_64/librados2-12.1.3-0.el7.centos.x86_64.rpm             \
      ../../RPMS/x86_64/python-rados-12.1.3-0.el7.centos.x86_64.rpm          \
      ../../RPMS/x86_64/librbd1-12.1.3-0.el7.centos.x86_64.rpm               \
      ../../RPMS/x86_64/python-rbd-12.1.3-0.el7.centos.x86_64.rpm            \
      ../../RPMS/x86_64/libcephfs2-12.1.3-0.el7.centos.x86_64.rpm            \
      ../../RPMS/x86_64/python-cephfs-12.1.3-0.el7.centos.x86_64.rpm         \
      ../../RPMS/x86_64/librgw2-12.1.3-0.el7.centos.x86_64.rpm               \
      ../../RPMS/x86_64/librados-devel-12.1.3-0.el7.centos.x86_64.rpm        \
      ../../RPMS/x86_64/libradosstriper1-12.1.3-0.el7.centos.x86_64.rpm      \
      ../../RPMS/x86_64/libradosstriper-devel-12.1.3-0.el7.centos.x86_64.rpm \
      ../../RPMS/x86_64/python-rgw-12.1.3-0.el7.centos.x86_64.rpm            \
      ../../RPMS/x86_64/ceph-common-12.1.3-0.el7.centos.x86_64.rpm           \
      ../../RPMS/x86_64/ceph-selinux-12.1.3-0.el7.centos.x86_64.rpm          \
      ../../RPMS/x86_64/ceph-base-12.1.3-0.el7.centos.x86_64.rpm             \
      ../../RPMS/x86_64/ceph-osd-12.1.3-0.el7.centos.x86_64.rpm              \
      ../../RPMS/x86_64/ceph-mon-12.1.3-0.el7.centos.x86_64.rpm              \
      ../../RPMS/x86_64/ceph-mds-12.1.3-0.el7.centos.x86_64.rpm              \
      ../../RPMS/x86_64/ceph-mgr-12.1.3-0.el7.centos.x86_64.rpm              \
      ../../RPMS/x86_64/ceph-12.1.3-0.el7.centos.x86_64.rpm                  \
      ../../RPMS/x86_64/ceph-radosgw-12.1.3-0.el7.centos.x86_64.rpm          \
      install.yuanguo.sh                                                     \
  $DIR



tar czvf ${DIR}.tar.gz  $DIR

rm -fr $DIR
