# ====================================================
# run scip to get solution and oracle_sol for training
# ====================================================

data=setcover
data=${data%/}
suffix=.lp

dat=/home/xlm/daggerSpace/training_files/scip-dagger/dat
training_files_base="/home/xlm/daggerSpace/training_files/scip-dagger"

resultDir=$training_files_base/clip-scratch/result
solutionDir=$training_files_base/bfs_solution
oracleSolutionDir=$training_files_base/solution_true_oracle

experiment=bfs_scip
set=./sets/allfullstrong_bfs.set

usage() {
  echo "Usage: $0 -d <data_path_under_dat> -i <subdir under data> -e <experiment> -x <suffix> -s <set>"
}

suffix=".lp.gz"
freq=1
dagger=0

while getopts ":hd:i:e:x:s:" arg; do
  case $arg in
    h)
      usage
      exit 0
      ;;
    d)
      data=${OPTARG%/}
      echo "test data: $data"
      ;;
    i)
      subdir=${OPTARG%/}
      echo "subdir: $subdir"
      ;;
    e)
      experiment=${OPTARG}
      echo "experiment: $experiment"
      ;;
    x)
      suffix=${OPTARG}
      echo "data suffix: $suffix"
      ;;
    s)
      set=${OPTARG}
      echo "scip set: $set"
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

dir=$dat/$data
# for fold in param train; do
for fold in $subdir; do
  if ! [ -d $resultDir/$data/$fold/$experiment ]; 
    then mkdir -p $resultDir/$data/$fold/$experiment
  fi
  if ! [ -d $solutionDir/$data/$fold ]; then 
    mkdir -p $solutionDir/$data/$fold
  fi
done

echo "Writing logs in $resultDir/$data/$experiment"
echo "Writing scip solutions in $solutionDir/$data"
echo "Writing blb solutions  in $oracleSolutionDir/$data"
echo "Reading data from      $oracleSolutionDir/$data"

echo "Running scip for $data"

# exit

# --------------------------------------------------muti start
tmp_fifofile="$$.fifo"
mkfifo $tmp_fifofile
exec 6<>$tmp_fifofile # FD6 to type of FIFO
rm $tmp_fifofile

thread_num=1
for ((i=0;i<${thread_num};i++)); do
    echo
done >&6

for fold in $subdir; do
  echo "Solving problems in $dir/$fold ..."
  for file in `ls $dir/$fold`; do
    read -u6
    {
      base=`sed "s/$suffix//g" <<< $file`
      if ! [ -e $solutionDir/$data/$fold/$base.sol ]; then
        # 跑SCIP并将sol存到output中
        echo "    " $base "  " $dir/$fold/$file
        bin/scipdagger -f $dir/$fold/$file --sol $solutionDir/$data/$fold/$base.sol -s $set > $resultDir/$data/$fold/$experiment/$base.log
        python ./case_study/02_reader.py scip -l $resultDir/$data/$fold/$experiment/$base.log -o $oracleSolutionDir/$data/$fold/$base.sol -b $base 
        echo "    ---->" done $base
      fi
      echo >&6
    } &
  done
done


wait
exec 6>&- #shutdown FD6
echo "over"

# --------------------------------------------------muti end
