## Capacity Block 예약(구매)하기 ##

P/Trn 타입 인스턴스에 대해서 AWS Management Console이나 AWS CLI로 예약할 수 있다.

### 방법 A: AWS Management Console에서 예약 ###
```
	1.	EC2 콘솔 접속 ➔ 좌측 메뉴에서 Capacity Reservations (용량 예약) 클릭.
	2.	Create Capacity Reservation (용량 예약 생성) 버튼 클릭.
	3.	Reservation type에서 Capacity Block for ML (ML용 용량 블록) 선택.
	4.	설정값 입력:
•	Instance type: (예: p5.48xlarge 등)
•	Target capacity: 필요 인스턴스 개수 (예: 4)
•	Duration: 사용 기간 (일 단위 또는 시간 단위)
•	Start date / End date: 시작 희망 일시
	5.	Search Capacity Blocks를 눌러 이용 가능한 블록 검색.
	6.	원하는 조건의 검색 결과 선택 후 Purchase (구매) 진행.
•	구매 완료 시 cr-xxxxxxxxxxxxxxxxx 형태의 **Capacity Block ID (Reservation ID)**가 발급됩니다.
```

### 방법 B: AWS CLI로 구매 예약 (검색 ➔ 구매) ###

① 사용 가능한 Capacity Block 검색:
```
aws ec2 describe-capacity-block-offerings \
    --instance-type p5.48xlarge \
    --instance-count 4 \
    --start-date-range 2026-08-01T00:00:00Z \
    --capacity-duration-hours 48 \
    --region us-east-1
```

② 오퍼링 ID(Offering Id)로 구매:
```
aws ec2 purchase-capacity-block \
    --capacity-block-offering-id cbo-0123456789abcdef0 \
    --instance-platform Linux/UNIX \
    --region us-east-1
```
구매 성공 시 출력 결과에 CapacityReservationId (cr-xxx...)가 출력된다.


## EC2 론치 시 Capacity Block ID 설정하기 ##
구매한 Capacity Block의 예약 시작 시간이 되면 해당 블록 ID를 지정해서 EC2를 생성해야 한다.

⚠️ 주의사항: Capacity Block은 Placement Group(배치 그룹), Subnet(가용 영역), Tenancy 사양이 예약된 내용과 정확히 일치한다.

### 1. AWS Console에서 론치 ###
```
  1.	EC2 콘솔 ➔ Launch Instances (인스턴스 시작) 클릭.
	2.	AMI, 인스턴스 유형(p5.48xlarge 등), Key Pair 등 기본 설정.
	3.	Advanced details (고급 세부 정보) 섹션을 펼침.
	4.	Capacity Reservation (용량 예약) 항목 설정:
•	Capacity Reservation option: Target by ID (ID로 타겟팅) 선택.
•	Capacity Reservation - Target ID: 예약해둔 Capacity Block ID (cr-xxxxxxxxxxxxxxxxx) 선택.
	5.	인스턴스 개수를 구매한 개수 이하로 설정 후 Launch Instance 클릭.
```

### 2. AWS CLI로 론치 ###
CLI 사용 시 --capacity-reservation-specification 파라미터로 ID를 주입.
```
aws ec2 run-instances \
    --image-id ami-xxxx \
    --instance-type p5.48xlarge \
    --count 4 \
    --key-name my-key-pair \
    --subnet-id subnet-xxxx \
    --instance-market-options 'MarketType=capacity-block' \
    --capacity-reservation-specification 'CapacityReservationTarget={CapacityReservationId=cr-xxxx}' \
    --region us-east-1
```

### 3. Terraform 설정 ###
Infrastructure as Code(IaC)로 작성할 때는 capacity_reservation_specification 블록을 사용.

```
resource "aws_instance" "gpu_node" {
  count         = 4
  ami           = "ami-xxxx"
  instance_type = "p5.48xlarge"
  subnet_id     = "subnet-xxxx"

  instance_market_options {
    market_type = "capacity-block"
  }

  capacity_reservation_specification {
    capacity_reservation_target {
      capacity_reservation_id = "cr-xxxx"
    }
  }
  # ...
}
```

### 4. AWS Parallel Cluster 예시 ###
```
Region: us-east-1
Image:
  Os: alinux2

HeadNode:
  InstanceType: m5.xlarge
  Networking:
    SubnetId: subnet-public-xxxx   # 헤드노드는 퍼블릭 서브넷 권장
  Ssh:
    KeyName: my-key-pair

Scheduling:
  Scheduler: slurm
  SlurmQueues:
    - Name: cb-p5-queue
      CapacityType: CAPACITY_BLOCK          # ← 핵심 1
      CapacityReservationTarget:            # ← 핵심 2 (큐 레벨)
        CapacityReservationId: cr-xxxx      #    구매한 Capacity Block ID
      Networking:
        SubnetIds:
          - subnet-private-xxxx             # ← CB와 동일한 AZ의 서브넷
        PlacementGroup:
          Enabled: true
      ComputeResources:
        - Name: cb-p5
          InstanceType: p5.48xlarge         # ← CB와 동일한 인스턴스 타입
          MinCount: 4                        # ← 핵심 3: Min = Max = CB 인스턴스 수
          MaxCount: 4
          Efa:
            Enabled: true                    # P5는 EFA 필수 권장
```

* MinCount = MaxCount (0보다 큰 값) Capacity Block 큐에서는 동일해야 한다. CB 예약에 포함된 모든 인스턴스가 static node로 관리되기 때문이다. 즉 오토스케일링(dynamic node)처럼 0까지 줄었다 늘었다 하지 않고, 블록 기간 동안 예약 수만큼 계속 떠 있다. 값은 구매한 인스턴스 개수와 일치시키야 한다.
* CapacityType: CAPACITY_BLOCK 이 값을 큐에 지정해야 ParallelCluster가 CB 방식(내부적으로 MarketType=capacity-block)으로 인스턴스를 띄운다. 
* 인스턴스 타입 / AZ 일치 - InstanceType은 CB로 예약한 타입과 정확히 동일해야 한다. (예 p5.48xlarge). 컴퓨트 서브넷은 CB가 위치한 단일 AZ와 같아야 한다.
* CapacityReservationTarget 위치 위 예시는 큐 레벨에 뒀는데, 컴퓨트 리소스별로 다른 CB를 쓰려면 ComputeResources 아래에도 둘 수 있다. 큐 레벨에 두면 그 큐의 모든 컴퓨트 리소스에 적용된다.
* 블록 시작 시간 전에 클러스터를 만들면, static 노드가 아직 용량이 없어 계속 launch 실패 상태가 된다. CB 예약 시작 시각이 되면 정상적으로 올라오기 때문에 클러스터 생성 자체는 미리 해둬도 된다.
* 블록 종료 시점에는 EC2가 인스턴스를 자동 종료하므로, 그 전에 체크포인트 저장/드레이닝이 되도록 학습 스크립트를 설계해야 한다. (30분 이상 여유를 두고 마무리하는 걸 권장)
* 여러 노드 분산 학습이면 PlacementGroup: Enabled: true + Efa: Enabled: true로 노드 간 통신 성능을 확보한다. 

## 러퍼런스 ##

* [EC2 Capacity Blocks for ML to reserve GPU capacity](https://aws.amazon.com/ko/blogs/aws/announcing-amazon-ec2-capacity-blocks-for-ml-to-reserve-gpu-capacity-for-your-machine-learning-workloads/)
```

