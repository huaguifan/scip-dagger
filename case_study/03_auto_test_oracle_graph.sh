#!/bin/bash
set -e

# ====================================================
# run oracle with diffrent prob
# ====================================================

usage() {
  echo "Usage: $0 -d <data_path_under_dat> -e <experiment> -x <suffix> -g <dagger> -p <prob> -n <numPasses> -a <delta>"
}

suffix=".lp.gz"
freq=1
dagger=0

while getopts ":hd:eg:x:p:n:a:" arg; do
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
    p)
      prob=${OPTARG}
      echo "prob: $prob"
      ;;
    n)
      numPasses=${OPTARG}
      echo "numPasses: $numPasses"
      ;;
    a)
      delta=${OPTARG}
      echo "prob delta: $delta"
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

for i in `seq 1 $numPasses`; do

    echo clean..................................................................
    make clean

    # change p in nodesel_oracle.c
    sed -i 's/double rnd_poss.*$/double rnd_poss='"$prob"';/g' /home/xlm/daggerSpace/he/he-dagger/src/nodesel_oracle.c
    
    # change experiment name in test_oraclegraph.sh
    sed -i 's/experiment=300.*$/experiment=300t_afsb_bfs_select_routes\/'"$prob"'/g' ./case_study/04_muti_run_oracle.sh 
    
    echo make...................................................................
    echo "    " iter-$i $prob
    make OPT=dbg READLINE=false -j16
    
    echo test...................................................................
    bash ./scripts/04_muti_run_oracle.sh -d $data -x $suffix -g $dagger 
    
    prob=$(echo $prob+$delta | bc |  awk '{printf "%.2f", $0}')

done
