#!/bin/bash
# Script to build (DEBUG, RElEASE) Secure GlenValley code

home_root=/home/debug/nms-ftfs/530_155320
svn_root=svn+ssh://svn.netmail.com/netmail/branches/support/secure_ftfs/5.3.0.155320

file_drop=/mnt/buildmachine/Netmail_GlenValley/RPMs/secure
file_prefix="NETMAIL-5.3.0"

mkdir -p "${file_drop}"

echo "Building Secure FTF 5.3.0_155320 from $svn_root"

cd $home_root
echo "  cleaning rpm-secure directory ..."
sudo rm -rf ./rpm-secure
mkdir -p $home_root/rpm-secure

echo "  validating workspace ..."
cd $home_root/secure
wd_info=`svn info | grep 'URL: ' | sed 's/URL: //'`
if [ "$wd_info" == "$svn_root" ]; then
echo "  Workspace is verified"
else
echo " *** $home_root/secure is not a workspace for $svn_root"
exit 1
fi

echo "  fetching latest version ..."
svn status | grep "^?" | sed 's/^? *//' | xargs -L1 -I{} echo rm -rf \"{}\" | sudo bash
svn revert -R .
svn up || exit $?
last_rev=`svn info | grep 'Revision:' | sed 's/Revision: //'`

echo "  Building Revision $last_rev RELEASE package ..."
cmake  -D CMAKE_BUILD_TYPE=release                     \
-D ASSERT_TYPE=print                            \
-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail         \
-D WITH_OOO=ON                                  \
-D WITH_SNMP=ON                                 \
. || exit $?

sudo make DESTDIR=$home_root/rpm-secure all install package || exit $?

sudo rm -rf ./rpm-secure
mkdir -p $home_root/rpm-secure
echo "  Building Revision $last_rev DEBUG package ..."
cmake   -D CMAKE_BUILD_TYPE=debug                       \
-D ASSERT_TYPE=crash                            \
-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail         \
-D WITH_OOO=ON                                  \
-D WITH_SNMP=ON                                 \
. || exit $?

sudo make DESTDIR=$home_root/rpm-secure all install package || exit $?

echo "Copying RPMs to $file_drop"
cp *.rpm $file_drop || exit $?

mkdir -p old_rpms
mv *.rpm old_rpms || exit $?

echo "--- BUILD COMPLETE ---"