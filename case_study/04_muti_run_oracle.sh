#!/bin/bash

# ====================================================
# run oracle to get result logs and stats
# ====================================================

# --poxis
#set -e errexit #$? cannot get command status anymore
set -e

usage() {
  echo "Usage: $0 -d <data_path_under_dat> -e <experiment> -x <suffix> -g <dagger>"
}

suffix=".lp.gz"
freq=1
dagger=0

while getopts ":hd:eg:x:" arg; do
  case $arg in
    h)
      usage
      exit 0
      ;;
    d)
      data=${OPTARG%/}
      echo "test data: $data"
      ;;
    e)
      experiment=${OPTARG}
      echo "experiment: $experiment"
      ;;
    g)
      dagger=${OPTARG}
      echo "run dagger: $dagger"
      ;;
    x)
      suffix=${OPTARG}
      echo "data suffix: $suffix"
      ;;
    :)
      echo "ERROR: -${OPTARG} requires an argument"
      usage
      exit 1
      ;;
    ?)
      echo "ERROR: unknown option -${OPTARG}"
      usage
      exit 1
      ;;
  esac
done

exit

# data=setcover/valid
# dagger=oracle
# suffix=.lp

experiment=300t_afsb_bfs_select_routes/0.60

dat=/home/xlm/daggerSpace/training_files/scip-dagger/dat
dir=$dat/$data

resultDir=/home/xlm/daggerSpace/training_files/scip-dagger/clip-scratch/result
solutionDir=/home/xlm/daggerSpace/training_files/scip-dagger/solution_true_oracle

# clear $resultDir/$data/$experiment
if [ -d $resultDir/$data/$experiment ]; then
  rm $resultDir/$data/$experiment/*
fi

# mkdir $resultDir/$data/$experiment
if ! [ -d $resultDir/$data/$experiment ]; then
  mkdir -p $resultDir/$data/$experiment
fi

# --------------------------------------------------muti start
tmp_fifofile="$$.fifo"
mkfifo $tmp_fifofile
exec 6<>$tmp_fifofile # FD6 to type of FIFO
rm $tmp_fifofile

thread_num=50
for ((i=0;i<${thread_num};i++)); do
    echo
done >&6


for file in `ls $dir`; do
  read -u6
  {
    base=`sed "s/$suffix//g" <<< $file`
    echo "    " $base
    # if [[ $dagger -eq 0 ]]; then
    if [[ "$dagger" == "policy" ]]; then
      echo policy
      bin/scipdagger -r $freq -s /home/xlm/daggerSpace/sets/allfullstrong_bfs.set -f $dir/$file --nodesel policy $searchPolicy -n $nodes -t $time &> $resultDir/$data/$experiment/$base.log
    else
      sol=$solutionDir/$data/$base.sol
      echo "    " oracle $experiment $base
      bin/scipdagger -r $freq -t 300 -s /home/xlm/daggerSpace/sets/allfullstrong_bfs.set -f $dir/$file -o $sol --nodesel oracle --nodeseltrj ./tmp/1 &> $resultDir/$data/$experiment/$base.log
      python ./case_study/reader.py oracle -l $resultDir/$data/$experiment/$base.log -o $resultDir/$data/$experiment/final_stats -b $base
    fi
    grep -o minrnd $resultDir/$data/$experiment/$base.log | wc -l >> $resultDir/$data/$experiment/minrnd.log
    grep -o maxrnd $resultDir/$data/$experiment/$base.log | wc -l >> $resultDir/$data/$experiment/maxrnd.log
    echo "    " done
    echo >&6
  } &
done

wait
exec 6>&- #shutdown FD6
echo "over"
# --------------------------------------------------muti end

