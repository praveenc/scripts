#!/bin/bash

typeset root_dir=/home/debug/svn/-automation
typeset testcase_dir=$root_dir/testcases
typeset data_dir=/home/debug/ci_data
typeset report=$testcase_dir/report.log
typeset suite=$testcase_dir/suite.log

if [ ! -d "$root_dir" ]; then
    echo "Automation Directory : $root_dir doesn't exist"
    exit 1
fi

if [ ! -d "$testcase_dir" ]; then
    echo "Testcase directory $testcase_dir not found!"
    exit 1
fi

if [ ! -f "$report" ]; then
   echo "Report log : $report not found!"
   exit 1
fi

if [ ! -f "$suite" ]; then
   echo "Suite log : $suite not found!"
   exit 1
fi

if [ ! -d "$data_dir" ]; then
   echo "Data dir: $data_dir not found!"
   echo "creating one..."
   `mkdir $data_dir`
fi

typeset rev_no=`egrep 'CPack\:.*generated' $suite | sed 's/.*-//g' | sed 's/_debug.*//g'`
typeset total=`egrep '(OK|FAIL|ERROR|CORE)' $report | wc -l`
typeset ok_cnt=`egrep '(OK)' $report | wc -l`
typeset fail_cnt=`egrep '(FAIL)' $report | wc -l`
typeset error_cnt=`egrep '(ERROR)' $report | wc -l`
typeset core_cnt=`egrep '(CORE)' $report | wc -l`

cat <<SUMMARY
==========================
BUILD: $rev_no
Host: `hostname`
==========================
PERCENT:`echo $ok_cnt $total | awk '{printf("%d",$1/$2 * 100); print"%"}'`
OK: $ok_cnt
FAIL: $fail_cnt
ERROR: $error_cnt
CORES: $core_cnt
==========================
Total Count: $total
==========================
SUMMARY

typeset report_records=`egrep '(FAIL|ERROR|CORE)' $report | sed 's/;.*#N//g' | sed 's/#.*$//g'`
cat <<RPT
$report_records
==========================
RPT

typeset fail_records=`egrep 'FAIL' $report | sed 's/;.*#N//g' | sed 's/#.*$//g' | awk '{print "\t{\"Status\":\"" $1"\",\"datetime\":\"" $2"\",\"testcase\":\"" $3"\"},"}'`

typeset core_records=`egrep 'CORE' $report | sed 's/;.*#N//g' | sed 's/#.*$//g' | awk '{print "\t{\"Status\":\"" $1"\",\"datetime\":\"" $2"\",\"testcase\":\"" $3"\"},"}'`

echo "Writing JSON to $data_dir..."
typeset today=`date +%Y-%m-%d`
cat >$data_dir/$today.json <<JSONDOC
{
  "build": "$rev_no",
  "revision": "$rev_no",
  "branch": "GlenValley",
  "rundate": "`date +%Y-%m-%d`",
  "totalcount": $total,
  "okcount": $ok_cnt,
  "failures": $fail_cnt,
  "cores": $core_cnt,
  "percentage" : "`echo $ok_cnt $total | awk '{printf("%d",$1/$2 * 100); print"%"}'`",
  "fail_records" : [
${fail_records%?}
  ],
  "core_records": [
${core_records%?}
  ]
}
JSONDOC

