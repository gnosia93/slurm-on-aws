## Capacity Block 예약(구매)하기 ##
AWS Management Console이나 AWS CLI로 예약할 수 있다.

### 방법 A: AWS Management Console에서 예약 ###
```
	1.	EC2 콘솔 접속 ➔ 좌측 메뉴에서 Capacity Reservations (용량 예약) 클릭.
	2.	Create Capacity Reservation (용량 예약 생성) 버튼 클릭.
	3.	Reservation type에서 Capacity Block for ML (ML용 용량 블록) 선택.
	4.	설정값 입력:
•	Instance type: (예: g6e.12xlarge 또는 g5.12xlarge 등)
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
    --instance-type g6e.12xlarge \
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

### 방법 A: AWS Console에서 론치 ###
```
  1.	EC2 콘솔 ➔ Launch Instances (인스턴스 시작) 클릭.
	2.	AMI, 인스턴스 유형(g6e.12xlarge 등), Key Pair 등 기본 설정.
	3.	Advanced details (고급 세부 정보) 섹션을 펼침.
	4.	Capacity Reservation (용량 예약) 항목 설정:
•	Capacity Reservation option: Target by ID (ID로 타겟팅) 선택.
•	Capacity Reservation - Target ID: 예약해둔 Capacity Block ID (cr-xxxxxxxxxxxxxxxxx) 선택.
	5.	인스턴스 개수를 구매한 개수 이하로 설정 후 Launch Instance 클릭.
```

### 방법 B: AWS CLI로 론치 (aws ec2 run-instances) ###
CLI 사용 시 --capacity-reservation-specification 파라미터로 ID를 주입.
```
aws ec2 run-instances \
    --image-id ami-0c55b159cbfafe1f0 \
    --instance-type g6e.12xlarge \
    --count 4 \
    --key-name my-key-pair \
    --subnet-id subnet-0123456789abcdef0 \
    --capacity-reservation-specification 'CapacityReservationTarget={CapacityReservationId=cr-0123456789abcdef0}' \
    --region us-east-1
```

### 방법 C: Terraform 코드로 설정 (aws_instance) ###
Infrastructure as Code(IaC)로 작성할 때는 capacity_reservation_specification 블록을 사용.

```
resource "aws_instance" "gpu_node" {
  count         = 4
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "g6e.12xlarge"
  subnet_id     = "subnet-0123456789abcdef0"

  # Capacity Block 타겟 지정
  capacity_reservation_specification {
    capacity_reservation_preference = "capacity-reservations-only"
    
    capacity_reservation_target {
      capacity_reservation_id = "cr-0123456789abcdef0"
    }
  }

  tags = {
    Name = "VLM-Training-Node-${count.index}"
  }
}
```

