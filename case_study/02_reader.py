import sys
import os
import logging
import argparse

class Node():
    def __init__(self, idx=-1, lowerbound=-1, primalbound=-1, dualbound=-1, branchvars=[]):
        self.idx = idx
        self.lowerbound = lowerbound
        self.primalbound = primalbound
        self.dualbound = dualbound
        self.branchvars = branchvars

def process_t_var(t_var):
    assert t_var[0] == "<"
    assert t_var[-1]== ">"
    tv = t_var[1:-1]
    while tv.startswith("t_"):
        tv = tv.replace("t_", "")
    return tv

def get_scip_node(f_lines, st, ed):
    # st, start line number
    # ed, end line number.   [st, ed]
    
    assert f_lines[ed-1].startswith("[src/scip/nodesel_bfs.c:300"), "Wrong selecting node number line!"
    
    idx, lowerbound = f_lines[ed-1].rstrip("\n").split(" ")[-2:]

    node = Node()
    node.idx = int(idx)
    node.lowerbound = float(lowerbound)

    branchvars = []
    for i in range(st-1, ed):
        f_l = f_lines[i].rstrip("\n")
        if f_l.startswith("<"):
            try:
                t_var, rel, value = f_l.split(" ")
            except:
                print("[bad t_var], %s" % f_l)
            if rel == ">=" and value == "1.0":
                branchvars.append(process_t_var(t_var))
    node.branchvars = branchvars
    
    # print(node.idx, node.branchvars)
    return node


def get_oracle_node(f_lines, st, ed):
    # st, start line number
    # ed, end line number

    # assert f_lines[ed-1].startswith("[src/scip/nodesel_bfs.c:300"), "Wrong selecting node number line!"
    if f_lines[ed-1].startswith("[src/scip/nodesel_bfs.c:300"):
        return Node()
    
    idx = f_lines[ed-1].rstrip("\n").split(" ")[-5]
    lowerbound = f_lines[ed-1].rstrip("\n").split(" ")[-1]
    primalbound = f_lines[ed-1].rstrip("\n").split(" ")[-3]

    node = Node()
    node.idx = int(idx)
    node.lowerbound = float(lowerbound)
    node.primalbound = float(primalbound)
    
    # print(node.idx, node.lowerbound, node.primalbound)
    
    return node


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'run',
        help='run scip or oracle',
        choices=['scip', 'oracle'],
    )
    parser.add_argument(
        '-l', '--log',
        help='input log file name',
        type=str,
        default="",
    )
    parser.add_argument(
       '-o', '--output',
       help='output file name',
       type=str,
       default='./tmp.sol',
    )
    parser.add_argument(
       '-b', '--base',
       help='base of input log',
       type=str,
       default='',
    )
    args = parser.parse_args()

    print(args)

    if len(sys.argv) != 5:
        print("Usage: \n\t python reader.py policy -l input_log -o output_file -b base !")
        sys.exit(-1)

    log_file_name = args.log
    policy = args.run

    # grep到日志文件中所有带lowerbound的行，并将行号存到line_no
    # scip和oracle日志格式不同，所以grep内容不同，后面统一一下
    if policy == "scip":
        os.system("grep -rEn 'Selecting node number' %s | cut -f1 -d':' > %s_tmp" % (log_file_name, log_file_name))
    else:
        os.system("grep -rEn 'final selecting' %s | cut -f1 -d':' > %s_tmp" % (log_file_name, log_file_name))

    line_no = [int(n.strip("\n")) for n in open("%s_tmp" % log_file_name, "r").readlines()] # 1,2,...

    log_file_lines = open("%s" % log_file_name, "r").readlines()


    nodelist = []
    max_lb_list_id = 0

    for i in range(len(line_no)):
        # 每读一行，就定义一个node对象，并append到nodelist中
        if i == 0:
            cur_node = get_oracle_node(log_file_lines, 1, line_no[i])
            nodelist.append(cur_node)
        else:
            # examine line_no[i-1]+1 --- line_no[i]
            if policy == "scip":
                cur_node = get_node(log_file_lines, line_no[i-1], line_no[i])
            else:
                cur_node = get_oracle_node(log_file_lines, line_no[i-1], line_no[i])
            nodelist.append(cur_node)
            if cur_node.lowerbound > nodelist[max_lb_list_id].lowerbound:
                max_lb_list_id = i

    # 如果是scip策略，则需要将BLB的分支变量即solution存储到args.output文件中
    if policy == "scip":
        print(nodelist[max_lb_list_id].branchvars)
        fout = open("%s" % args.output, "w")
        fout.write("Objective Value:                    %.3f\n" % nodelist[max_lb_list_id].lowerbound)
        for var in nodelist[max_lb_list_id].branchvars:
            fout.write("%s           1\n" % var)

        fout.close()
        os.system("rm %s_tmp" % log_file_name)

    # 如果是oracle策略，需要将日志中nodeidx，BLB，curPB，minPB存储到args.output文件中
    else:
        sorted(nodelist, key=lambda k:k.primalbound, reverse=False)
        min_primalbound = nodelist[-1].primalbound

        max_lb_list_id = 0
        for i in range(len(nodelist)):
            if nodelist[i].lowerbound <= min_primalbound and nodelist[i].lowerbound > nodelist[max_lb_list_id].lowerbound:
                max_lb_list_id = i

        fout = open("%s" % args.output, "a")
        fout.write("%s   %d    %.3f  %.3f %.3f\n" % (args.base, nodelist[max_lb_list_id].idx, nodelist[max_lb_list_id].lowerbound, nodelist[max_lb_list_id].primalbound, min_primalbound))
        fout.close()

    os.system("rm %s_tmp" % log_file_name)
    print("Done")