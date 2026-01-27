```
ansible-playbook -i hosts.ini slurm_deploy.yml
```
* 확인: 마스터 노드에서 sinfo를 입력하여 노드들이 idle 상태인지 확인합니다.



```
ansible-playbook -i hosts.ini gpu-setup.yml
```
