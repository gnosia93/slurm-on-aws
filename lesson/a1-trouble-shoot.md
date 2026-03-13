```
$ sinfo -N
NODELIST     NODES PARTITION STATE 
gpu-st-ml-1      1      gpu* down~ 
gpu-st-ml-2      1      gpu* down~ 
ubuntu@ip-10-0-0-130:~$ scontrol show node gpu-st-ml-1
NodeName=gpu-st-ml-1 CoresPerSocket=1 
   CPUAlloc=0 CPUEfctv=32 CPUTot=32 CPULoad=0.00
   AvailableFeatures=static,g7e.8xlarge,ml,efa,gpu
   ActiveFeatures=static,g7e.8xlarge,ml,efa,gpu
   Gres=gpu:rtxproserver6000:1
   NodeAddr=10.0.10.166 NodeHostName=gpu-st-ml-1 
   RealMemory=249036 AllocMem=0 FreeMem=N/A Sockets=32 Boards=1
   State=DOWN+CLOUD+POWERED_DOWN ThreadsPerCore=1 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=gpu 
   BootTime=None SlurmdStartTime=None
   LastBusyTime=Unknown ResumeAfterTime=None
   CfgTRES=cpu=32,mem=249036M,billing=32
   AllocTRES=
   CurrentWatts=0 AveWatts=0
   
   Reason=Static node maintenance: unhealthy node is being replaced [root@2026-03-13T04:18:07]

ubuntu@ip-10-0-0-130:~$ sudo tail -50 /var/log/parallelcluster/clustermgtd | grep -i "unhealthy\|replace\|launch\|fail\|error"
2026-03-13 04:55:06,717 - [slurm_plugin.clustermgtd:_maintain_nodes] - INFO - Following nodes are currently in replacement: (x2) ['gpu-st-ml-2', 'gpu-st-ml-1']
2026-03-13 04:55:06,717 - [slurm_plugin.clustermgtd:_maintain_nodes] - INFO - Found the following unhealthy static nodes: (x2) ['gpu-st-ml-1(10.0.10.222)', 'gpu-st-ml-2(10.0.10.102)']
2026-03-13 04:55:06,834 - [slurm_plugin.clustermgtd:_handle_unhealthy_static_nodes] - INFO - Setting unhealthy static nodes to DOWN
2026-03-13 04:55:06,850 - [slurm_plugin.clustermgtd:_handle_unhealthy_static_nodes] - INFO - Launching new instances for unhealthy static nodes
2026-03-13 04:55:06,850 - [slurm_plugin.instance_manager:_launch_instances] - INFO - Launching best-effort instances for nodes (x2) ['gpu-st-ml-1', 'gpu-st-ml-2']
2026-03-13 04:55:06,850 - [slurm_plugin.fleet_manager:run_instances] - INFO - Launching instances with run_instances API. Parameters: {'MinCount': 1, 'MaxCount': 2, 'LaunchTemplate': {'LaunchTemplateName': 'slurm-on-aws-gpu-ml', 'Version': '$Latest'}}
2026-03-13 04:55:08,511 - [slurm_plugin.fleet_manager:launch_ec2_instances] - INFO - Launched the following instances (x2) ['i-0119284e3d911b6ee', 'i-0c3b889bf3a3ca6d3']
2026-03-13 04:55:09,414 - [slurm_plugin.instance_manager:_update_slurm_node_addrs] - INFO - Nodes are now configured with instances (x2) ["('gpu-st-ml-1', EC2Instance(id='i-0119284e3d911b6ee', private_ip='10.0.10.166', hostname='ip-10-0-10-166', all_private_ips={'10.0.10.166'}, launch_time=datetime.datetime(2026, 3, 13, 4, 55, 8, tzinfo=tzlocal()), slurm_node=None))", "('gpu-st-ml-2', EC2Instance(id='i-0c3b889bf3a3ca6d3', private_ip='10.0.10.89', hostname='ip-10-0-10-89', all_private_ips={'10.0.10.89'}, launch_time=datetime.datetime(2026, 3, 13, 4, 55, 8, tzinfo=tzlocal()), slurm_node=None))"]
2026-03-13 04:55:09,414 - [slurm_plugin.instance_manager:_best_effort_node_assignment] - INFO - Successful launched and assigned all instances for nodes (x2) ['gpu-st-ml-1', 'gpu-st-ml-2']
2026-03-13 04:55:09,414 - [slurm_plugin.clustermgtd:_handle_unhealthy_static_nodes] - INFO - After node maintenance, following nodes are currently in replacement: (x2) ['gpu-st-ml-2', 'gpu-st-ml-1']
2026-03-13 04:55:09,414 - [slurm_plugin.slurm_resources:is_bootstrap_failure] - WARNING - Node bootstrap error: Node gpu-st-ml-1(10.0.10.222) is currently in replacement and no backing instance, node state: DOWN+CLOUD+POWERED_DOWN
2026-03-13 04:55:09,414 - [slurm_plugin.slurm_resources:is_bootstrap_failure] - WARNING - Node bootstrap error: Node gpu-st-ml-2(10.0.10.102) is currently in replacement and no backing instance, node state: DOWN+CLOUD+POWERED_DOWN
2026-03-13 04:55:09,414 - [slurm_plugin.clustermgtd:_handle_bootstrap_failure_nodes] - WARNING - Found the following bootstrap failure nodes: (x2) ['gpu-st-ml-1(10.0.10.222)', 'gpu-st-ml-2(10.0.10.102)']
2026-03-13 04:55:09,415 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:56:07,264 - [slurm_plugin.clustermgtd:_maintain_nodes] - INFO - Following nodes are currently in replacement: (x2) ['gpu-st-ml-2', 'gpu-st-ml-1']
2026-03-13 04:56:07,264 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:57:07,154 - [slurm_plugin.clustermgtd:_maintain_nodes] - INFO - Following nodes are currently in replacement: (x2) ['gpu-st-ml-2', 'gpu-st-ml-1']
2026-03-13 04:57:07,154 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:58:07,116 - [slurm_plugin.clustermgtd:_maintain_nodes] - INFO - Following nodes are currently in replacement: (x2) ['gpu-st-ml-2', 'gpu-st-ml-1']
2026-03-13 04:58:07,116 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
ubuntu@ip-10-0-0-130:~$ sudo tail -30 /var/log/parallelcluster/slurm_resume.log
ubuntu@ip-10-0-0-130:~$ sudo grep -i "error\|fail\|capacity" /var/log/parallelcluster/clustermgtd | tail -20
2026-03-13 04:45:07,214 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:46:07,175 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:47:07,224 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:48:07,238 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:49:07,161 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:50:07,208 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:51:07,151 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:52:07,169 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:53:07,187 - [slurm_plugin.capacity_block_manager:_retrieve_capacity_blocks_from_fleet_config] - INFO - Retrieving Capacity Blocks from fleet configuration.
2026-03-13 04:53:07,197 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:54:07,152 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 4}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:55:09,414 - [slurm_plugin.slurm_resources:is_bootstrap_failure] - WARNING - Node bootstrap error: Node gpu-st-ml-1(10.0.10.222) is currently in replacement and no backing instance, node state: DOWN+CLOUD+POWERED_DOWN
2026-03-13 04:55:09,414 - [slurm_plugin.slurm_resources:is_bootstrap_failure] - WARNING - Node bootstrap error: Node gpu-st-ml-2(10.0.10.102) is currently in replacement and no backing instance, node state: DOWN+CLOUD+POWERED_DOWN
2026-03-13 04:55:09,414 - [slurm_plugin.clustermgtd:_handle_bootstrap_failure_nodes] - WARNING - Found the following bootstrap failure nodes: (x2) ['gpu-st-ml-1(10.0.10.222)', 'gpu-st-ml-2(10.0.10.102)']
2026-03-13 04:55:09,415 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:56:07,264 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:57:07,154 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:58:07,116 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 04:59:07,254 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
2026-03-13 05:00:07,170 - [slurm_plugin.clustermgtd:_handle_protected_mode_process] - INFO - Partitions bootstrap failure count: {'gpu': {'ml': 6}}, cluster will be set into protected mode if protected failure count reaches threshold 10
ubuntu@ip-10-0-0-130:~$
``` 
