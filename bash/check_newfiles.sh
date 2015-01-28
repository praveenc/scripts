#!/bin/bash

sudo su debug <<CHECKFILES
home_root=/home/debug/nms-iberville
cd $home_root 

if [ -f platform_now_files.txt ]; then
	cp -f platform_now_files.txt platform_prev_files.txt
	rm platform_now_files.txt
else
	tree -i platform/ > platform_prev_files.txt
fi

svn up platform/
tree -i platform/ > platform_now_files.txt
any_new_files=`diff $home_root/platform_prev_files.txt $home_root/platform_now_files.txt`

if [ -z "$any_new_files" ]; then
	echo "No new files since last build"
else
	echo "${any_new_files}"
	echo -e "
	\n--- New Files Found in this build --\n
	If they need to be added to InstallShield then update warp_versions.bat here\n
	myserver/trunk/platform/HudsonBuild/verpatch/warp_versions.bat
	\n\n
	If they should be ignored by InstallShield then update to_ignore_from_install_shield.txt here\n
	myserver/trunk/platform/HudsonBuild/to_ignore_from_install_shield.txt\n
	------------------------------------
	"
	echo "*** BUILD ABORTED ****"
	exit 1
fi
CHECKFILES
