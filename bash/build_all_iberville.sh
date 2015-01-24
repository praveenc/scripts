#!/bin/bash
#-----------------------------------------------------------------------
# Script to build platform, secure, secure transition and webadmin
# Author: Praveen Chamarthi
# Date: July 2014
# SVN Path: svn+ssh://svn.netmail.com/netmail/trunk/platform/HudsonBuild
#-----------------------------------------------------------------------

if [ "$#" -lt 1 ]; then
	echo  "Missing Build Number param..."
	echo  "Usage:"
	echo  "		$0 <BUILD_NUMBER>"
	echo  " 	e.g. $0 1234"
	echo  " 	e.g. $0 1234 [all]"
	exit 1
else
	typeset build_number="$1"
fi

if [ "$2" == "all" ]; then
	typeset release=RELEASE
	echo "Building DEBUG, RELEASE versions ..."
fi

#A few VARIABLES
typeset svn_root=svn+ssh://svn.netmail.com/netmail
typeset svn_tag_root=svn+ssh://svn.netmail.com/netmail/tags/Iberville
typeset prod_version=5.3.1.$build_number
typeset home_root=/home/debug/nms-iberville
typeset build_root=$home_root/build
typeset rpm_share=/mnt/buildmachine/Netmail_trunk/${prod_version}/
typeset workspace=/mnt/build_workspace

#echo "Building Version: ${prod_version} "

#
cd $home_root/platform
echo "cleaning platform workspace..."
# Cleanup any old, changed files in workspace
svn status | grep "^?" | sed 's/^? *//' | xargs -L1 -I{} echo rm -rf \"{}\" | sudo bash
svn revert -R .
echo "updating platform workspace..."
svn up
last_rev_platform=`svn info | grep 'Revision:' | sed 's/Revision: //'`

cd $home_root/secure
echo "cleaning secure workspace..."
# Cleanup any old, changed files in workspace
svn status | grep "^?" | sed 's/^? *//' | xargs -L1 -I{} echo rm -rf \"{}\" | sudo bash
echo "updating secure workspace..."
svn revert -R .
svn up
last_rev_secure=`svn info | grep 'Revision:' | sed 's/Revision: //'`

# secure-transition build
cd $home_root/secure-transition
echo "cleaning secure-transition workspace..."
# Cleanup any old, changed files in workspace
svn status | grep "^?" | sed 's/^? *//' | xargs -L1 -I{} echo rm -rf \"{}\" | sudo bash
echo "updating secure-transition workspace..."
svn revert -R .
svn up
last_rev_secure=`svn info | grep 'Revision:' | sed 's/Revision: //'`


cd $home_root/webadmin
echo "cleaning webadmin workspace..."
# Cleanup any old files
svn status | grep "^?" | sed 's/^? *//' | xargs -L1 -I{} echo rm -rf \"{}\" | sudo bash
svn revert -R .
echo "updating webadmin workspace..."
svn up
last_rev_webadmin=`svn info | grep 'Revision:' | sed 's/Revision: //'`

cd $home_root/testtools
echo "cleaning testtools workspace..."
svn status | grep "^?" | sed 's/^? *//' | xargs -L1 -I{} echo rm -rf \"{}\" | sudo bash
svn revert -R .
echo "updating testtools workspace..."
svn up


echo "Cleaning Build folders ..."
sudo rm -rf $build_root
mkdir -p $build_root/{platform,secure,secure-transition,webadmin,rpm-platform,rpm-secure,rpm-securetransition,rpm-webadmin,rpm-testtools}

#PLATFORM BUILD
echo "Building Platform DEBUG (crash)..."
mkdir -p $build_root/platform
cd $build_root/platform

# Configure CMake with default (DEBUG) params
cmake	-D CMAKE_BUILD_TYPE=debug			\
	-D ASSERT_TYPE=crash				\
	-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
	-D DATA_DIR=/opt/ma/data/netmail		\
	-D REV_TYPE=${build_number}			\
	../../platform || exit $?

rm -rf $build_root/rpm-platform
mkdir -p $build_root/rpm-platform
# Build, install and package RPM
make DESTDIR=$build_root/rpm-platform clean all install package || exit $?

if [ "$release" == "RELEASE" ]; then

	echo "Building Platform RELEASE ..."
	cd $build_root/platform

	# Configure CMake with default (RELEASE) params
	cmake	-D CMAKE_BUILD_TYPE=release			\
		-D ASSERT_TYPE=print				\
		-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
		-D DATA_DIR=/opt/ma/data/netmail		\
		-D REV_TYPE=${build_number}			\
		../../platform || exit $?

	rm -rf $build_root/rpm-platform
	mkdir -p $build_root/rpm-platform
	# Build, install and package RPM
	make DESTDIR=$build_root/rpm-platform clean all install package || exit $?

fi

echo "Creating directory for RPMs under $rpm_share"
sudo mkdir -p $rpm_share/RPMs

#Copy RPM to Share folder on Archive Build Machine
# Share Folder: \\10.10.23.159\Builds\Netmail_trunk\RPMs folder
echo "copying platform rpm to $rpm_share ..."
find $build_root/platform -maxdepth 1 -iname \*.rpm -exec sudo cp "{}" $rpm_share/RPMs \;

#SECURE BUILD
echo "Building secure DEBUG ..."
mkdir -p $build_root/secure
cd $build_root/secure

cmake	-D CMAKE_BUILD_TYPE=debug			\
	-D ASSERT_TYPE=crash				\
	-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
	-D DATA_DIR=/opt/ma/data/netmail		\
	-D REV_TYPE=${build_number}			\
	../../secure || exit $?

rm -rf $build_root/rpm-secure
mkdir -p $build_root/rpm-secure

make DESTDIR=$build_root/rpm-secure clean all install package || exit $?

if [ "$release" == "RELEASE" ]; then

	echo "Building secure RELEASE ..."
	cd $build_root/secure

	cmake	-D CMAKE_BUILD_TYPE=release			\
		-D ASSERT_TYPE=print				\
		-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
		-D DATA_DIR=/opt/ma/data/netmail		\
		-D REV_TYPE=${build_number}			\
		../../secure || exit $?

	rm -rf $build_root/rpm-secure
	mkdir -p $build_root/rpm-secure

	make DESTDIR=$build_root/rpm-secure clean all install package || exit $?
fi

#SECURE TRANSITION BUILD
echo "Building SECURE-TRANSITION DEBUG ..."
mkdir -p $build_root/secure-transition
cd $build_root/secure-transition

cmake	-D CMAKE_BUILD_TYPE=debug			\
	-D ASSERT_TYPE=crash				\
	-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
	-D DATA_DIR=/opt/ma/data/netmail		\
	-D REV_TYPE=${build_number}			\
	../../secure-transition || exit $?

rm -rf $build_root/rpm-securetransition
mkdir -p $build_root/rpm-securetransition

make DESTDIR=$build_root/rpm-securetransition clean all package || exit $?

if [ "$release" == "RELEASE" ]; then

	echo "Building SECURE-TRANSITION RELEASE ..."
	cd $build_root/secure-transition

	cmake	-D CMAKE_BUILD_TYPE=release			\
		-D ASSERT_TYPE=print				\
		-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
		-D DATA_DIR=/opt/ma/data/netmail		\
		-D REV_TYPE=${build_number}			\
		../../secure-transition || exit $?

	rm -rf $build_root/rpm-securetransition
	mkdir -p $build_root/rpm-securetransition

	make DESTDIR=$build_root/rpm-securetransition clean all package || exit $?
fi


echo "copying secure rpm to $rpm_share ..."
find $build_root/secure -maxdepth 1 -iname \*.rpm -exec sudo cp "{}" $rpm_share/RPMs \;
echo "copying secure-transition rpm to $rpm_share ..."
find $build_root/secure-transition -maxdepth 1 -iname \*.rpm -exec sudo cp "{}" $rpm_share/RPMs \;


echo "Building webadmin DEBUG ..."
mkdir -p $build_root/webadmin
cd $build_root/webadmin

cmake	-D CMAKE_BUILD_TYPE=debug			\
	-D ASSERT_TYPE=crash				\
	-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
	-D DATA_DIR=/opt/ma/data/netmail		\
	-D REV_TYPE=${build_number}			\
	../../webadmin || exit $?

rm -rf $build_root/rpm-webadmin
mkdir -p $build_root/rpm-webadmin

make DESTDIR=$build_root/rpm-webadmin clean all install package || exit $?

if [ "$release" == "RELEASE" ]; then

	echo "Building webadmin RELEASE ..."
	cd $build_root/webadmin

	cmake	-D CMAKE_BUILD_TYPE=release			\
		-D ASSERT_TYPE=print				\
		-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
		-D DATA_DIR=/opt/ma/data/netmail		\
		-D REV_TYPE=${build_number}			\
		../../webadmin || exit $?

	rm -rf $build_root/rpm-webadmin
	mkdir -p $build_root/rpm-webadmin

	make DESTDIR=$build_root/rpm-webadmin clean all install package || exit $?
fi

echo "copying webadmin rpm to $rpm_share ..."
find $build_root/webadmin -maxdepth 1 -iname \*.rpm -exec sudo cp "{}" $rpm_share/RPMs \;

echo "Building TestTools ..."
mkdir -p $build_root/testtools
cd $build_root/testtools

# Configure CMake with default (DEBUG) params
cmake	-D CMAKE_BUILD_TYPE=debug			\
	-D ASSERT_TYPE=crash				\
	-D CMAKE_INSTALL_PREFIX=/opt/ma/netmail		\
	-D DATA_DIR=/opt/ma/data/netmail		\
	-D REV_TYPE=${build_number}			\
	-D PLATFORM_BINARY_DIR=$build_root/platform \
	../../testtools || exit 0

sudo make DESTDIR=$build_root/rpm-testtools all install package || exit 0

echo "Copying TESTTOOLS RPM to $rpm_share ..."
find $build_root/testtools -maxdepth 1 -iname \*TEST\-TOOLS\*.rpm -exec sudo cp "{}" $rpm_share/RPMs \;

echo "*********END OF LINUX BUILD**********"
