## Running the experiments

### Set Covering
```
# 运行SCIP得到solutions（TODO：收集训练数据即特征向量）
bash ./case_study/muti_run_scip.sh -d setcover -i valid -e bfs_scip -x .lp -s ./sets/allfullstrong_bfs.set
# 运行oracle策略，得到概率为i*delta+prob下的统计结果，i从0到numPasses-1
bash ./case_study/03_auto_test_oracle_graph.sh -d setcover/valid -x .lp -g oracle -p prob -n numPasses -a delta