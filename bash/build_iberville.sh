#!/bin/bash


if [ "$#" -lt 1 ]; then
	echo "**ERROR - Missing Build Number **"
	exit 1
else
	build_number="$1"
	echo "Building Version: 5.3.1.${build_number} ..."
fi

sudo su debug <<BUILD
cd /home/debug/nms-iberville
svn up platform/
cp platform/HudsonBuild/*.sh ./
chmod +x build_all_iberville.sh
chmod +x tag_all_iberville.sh
./build_all_iberville.sh $build_number
BUILD
