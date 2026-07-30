CapacityType은 큐 레벨 설정이고 한 큐에 하나만 지정할 수 있다. Spot과 OnDemand를 둘 다 쓰려면 큐를 나눠야 한다.

```
SlurmQueues:
  - Name: gpu-spot
    CapacityType: SPOT
    ...
  - Name: gpu-ondemand
    CapacityType: ONDEMAND
    ...
```

단, "무조건 별도 큐가 필요"한 건 Spot과 OnDemand를 동시에 쓰고 싶을 때이다. 만약 "그냥 Spot만 쓰겠다"면 기존 gpu 큐의 CapacityType을 SPOT으로 바꾸기만 하면 된다.

* Spot만 → 큐 1개, CapacityType: SPOT
* OnDemand만 → 큐 1개, CapacityType: ONDEMAND
* 둘 다 (fallback) → 큐 2개

실행시 partition 파라미터에 sport 을 먼저 지정한다. 
```
sbatch --partition=gpu-spot,gpu-ondemand train.sh
```
Slurm은 나열된 순서대로 파티션을 시도하므로, 앞에 있는 gpu-spot을 먼저 잡으려 하고 안 되면 gpu-ondemand로 넘어간다.

#### Spot 중단 시 작업을 자동으로 다시 큐에 넣으려면: ###


```bash
#SBATCH --requeue
#SBATCH --partition=gpu-spot,gpu-ondemand
```
