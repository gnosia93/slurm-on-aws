## promQL ##
### 1. 데이터 타입 ###
Prometheus 메트릭은 4가지 타입이 있다.
```
Counter   - 계속 증가만 하는 값 (요청 수, 전송 바이트 등)
Gauge     - 올라갔다 내려갔다 하는 값 (GPU 사용률, 온도, 메모리 등)
Histogram - 값의 분포 (요청 응답시간 분포)
Summary   - Histogram과 비슷, 클라이언트에서 분위수 계산
```
* Gauge 예시:   DCGM_FI_DEV_GPU_UTIL = 85      (지금 GPU 85% 사용 중)
* Counter 예시: node_network_receive_bytes_total = 123456789 (누적 수신 바이트)

### 2. 셀렉터 (데이터 선택) ###
```
# 메트릭 이름만
DCGM_FI_DEV_GPU_UTIL

# 라벨 정확히 매칭
DCGM_FI_DEV_GPU_UTIL{gpu="0"}

# 라벨 여러 개 AND 조건
DCGM_FI_DEV_GPU_UTIL{gpu="0", instance="compute-1:9400"}

# 정규식 매칭
DCGM_FI_DEV_GPU_UTIL{instance=~"compute-.*"}

# 부정 매칭
DCGM_FI_DEV_GPU_UTIL{gpu!="0"}

# 정규식 부정
DCGM_FI_DEV_GPU_UTIL{instance!~"head-.*"}


연산자 정리:

=    정확히 일치
!=   불일치
=~   정규식 일치
!~   정규식 불일치
```

### 3. 범위 벡터 (시간 범위 선택) ###
```
# 최근 5분간의 데이터 포인트들
DCGM_FI_DEV_GPU_UTIL[5m]

# 시간 단위
s  초
m  분
h  시간
d  일
w  주
y  년

# 예시
DCGM_FI_DEV_GPU_UTIL[30s]   # 최근 30초
DCGM_FI_DEV_GPU_UTIL[1h]    # 최근 1시간
node_cpu_seconds_total[10m]  # 최근 10분
범위 벡터는 단독으로 그래프에 못 그립니다. 반드시 함수(rate, avg_over_time 등)와 함께 써야 합니다.
```

### 4. 핵심 함수 ###
Counter용 함수 - Counter는 누적값이라 그대로 보면 의미 없고, 변화율을 봐야 합니다:
```
# rate: 초당 변화율 (가장 많이 씀)
rate(node_network_receive_bytes_total[5m])
# → 최근 5분간 초당 평균 수신 바이트 = 네트워크 throughput

# irate: 마지막 두 포인트 기준 순간 변화율 (스파이크 감지)
irate(node_network_receive_bytes_total[5m])

# increase: 시간 범위 동안 총 증가량
increase(node_network_receive_bytes_total[1h])
# → 최근 1시간 동안 총 수신 바이트


Gauge용 함수
# 시간 범위 평균
avg_over_time(DCGM_FI_DEV_GPU_UTIL[5m])

# 시간 범위 최대/최소
max_over_time(DCGM_FI_DEV_GPU_UTIL[1h])
min_over_time(DCGM_FI_DEV_GPU_UTIL[1h])

# 시간 범위 표준편차 (변동성 확인)
stddev_over_time(DCGM_FI_DEV_GPU_UTIL[10m])
집계 함수 (Aggregation)
# 전체 평균
avg(DCGM_FI_DEV_GPU_UTIL)

# 라벨별 그룹핑
avg by (instance) (DCGM_FI_DEV_GPU_UTIL)        # 노드별 평균
sum by (instance) (DCGM_FI_DEV_MEM_USED)         # 노드별 메모리 합계
max by (gpu) (DCGM_FI_DEV_GPU_TEMP)              # GPU별 최대 온도
count by (instance) (DCGM_FI_DEV_GPU_UTIL > 90)  # 노드별 90% 넘는 GPU 수

# 특정 라벨 제외하고 집계
avg without (gpu) (DCGM_FI_DEV_GPU_UTIL)  # gpu 라벨 빼고 나머지로 그룹핑

# 상위/하위 N개
topk(5, DCGM_FI_DEV_GPU_UTIL)    # GPU 사용률 상위 5개
bottomk(5, DCGM_FI_DEV_GPU_UTIL) # GPU 사용률 하위 5개
```

### 5. 산술/비교 연산 ###
```
# 산술
DCGM_FI_DEV_MEM_USED / DCGM_FI_DEV_MEM_TOTAL * 100  # GPU 메모리 사용률 %

# 비교 (필터링)
DCGM_FI_DEV_GPU_UTIL > 90          # 90% 넘는 것만
DCGM_FI_DEV_GPU_TEMP >= 80         # 80도 이상
node_filesystem_avail_bytes < 1e9  # 여유 공간 1GB 미만

# bool 수정자 (0/1 반환)
DCGM_FI_DEV_GPU_UTIL > bool 90    # 90 넘으면 1, 아니면 0
6. HPC/GPU 모니터링 실전 쿼리
GPU 모니터링
# GPU 사용률 (전체 노드)
avg by (instance) (DCGM_FI_DEV_GPU_UTIL)

# GPU 메모리 사용률
DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100

# GPU 온도 80도 넘는 GPU 찾기
DCGM_FI_DEV_GPU_TEMP > 80

# GPU ECC 에러 (증가하면 하드웨어 문제)
rate(DCGM_FI_DEV_ECC_DBE_VOL_TOTAL[5m]) > 0

# SM Clock throttling 감지
DCGM_FI_DEV_CLOCK_THROTTLE_REASONS != 0

# GPU Power 사용량
DCGM_FI_DEV_POWER_USAGE

# Tensor Core 활용률 (학습 효율)
DCGM_FI_PROF_PIPE_TENSOR_ACTIVE
네트워크 모니터링 (EFA/NCCL)
# 노드별 네트워크 throughput (bytes/sec)
rate(node_network_receive_bytes_total{device="eth0"}[5m])
rate(node_network_transmit_bytes_total{device="eth0"}[5m])

# 네트워크 에러
rate(node_network_receive_errs_total[5m]) > 0
rate(node_network_transmit_drop_total[5m]) > 0
노드 리소스
# CPU 사용률
100 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

# 메모리 사용률
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# 디스크 사용률
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# Lustre throughput (Lustre exporter 있을 때)
rate(lustre_read_bytes_total[5m])
rate(lustre_write_bytes_total[5m])
Slurm 클러스터
# 실행 중인 잡 수
slurm_queue_running

# 대기 중인 잡 수
slurm_queue_pending

# 노드 상태별 수
slurm_nodes{state="idle"}
slurm_nodes{state="allocated"}
slurm_nodes{state="down"}
```
### 7. 알림 규칙 예시 ###
```
# /etc/prometheus/alert.rules.yml
groups:
  - name: gpu_alerts
    rules:
      - alert: GPUHighTemperature
        expr: DCGM_FI_DEV_GPU_TEMP > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "GPU 온도 85도 초과 ({{ $labels.instance }})"

      - alert: GPUECCError
        expr: rate(DCGM_FI_DEV_ECC_DBE_VOL_TOTAL[5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "GPU ECC Double Bit Error 감지 ({{ $labels.instance }})"

      - alert: GPUMemoryFull
        expr: DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) > 0.95
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "GPU 메모리 95% 초과 ({{ $labels.instance }})"

      - alert: NodeDiskFull
        expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "디스크 여유 공간 10% 미만 ({{ $labels.instance }})"
```
### 8. 디버깅 팁 ###
```
# 1. 데이터 수집 확인
up                                    # 모든 타겟 상태
up{job="dcgm"}                        # DCGM exporter만

# 2. 메트릭 존재 여부 확인
count({__name__=~"DCGM.*"})           # DCGM 메트릭 몇 개 있나
count({__name__=~"node.*"})           # Node 메트릭 몇 개 있나

# 3. 라벨 확인
group by (__name__) ({job="dcgm"})    # DCGM job의 모든 메트릭 이름 나열

# 4. 특정 시점 데이터 확인 (API)
# curl 'http://localhost:9090/api/v1/query?query=up&time=2026-03-20T10:00:00Z'
```
# 5. scrape 간격 확인
scrape_duration_seconds{job="dcgm"}   # 스크래핑에 걸리는 시간
scrape_samples_scraped{job="dcgm"}    # 스크래핑된 샘플 수

## 그라파나 ##
Grafana 대시보드 만드는 건 결국 이겁니다:
```
1. 패널 추가 (Add Panel)
2. PromQL 쿼리 입력 (데이터)
3. 시각화 타입 선택 (그래프, 게이지, 테이블 등)
4. 옵션 조정 (색상, 임계값, 범례 등)
2번이 PromQL이고, 3~4번은 UI에서 드롭다운 선택하는 거라 별도 언어가 필요 없어요.

예를 들어 GPU 사용률 대시보드 패널 하나 만든다면:

쿼리:  avg by (instance) (DCGM_FI_DEV_GPU_UTIL)
타입:  Time Series (선 그래프)
단위:  Percent (0-100)
임계값: 90 이상 빨간색
이게 끝입니다. PromQL만 쓸 줄 알면 나머지는 직관적이에요.

추가로 알면 좋은 건 Grafana 변수(Variables) 기능인데, 드롭다운으로 노드나 GPU를 선택할 수 있게 해줍니다:

변수 이름: instance
쿼리: label_values(DCGM_FI_DEV_GPU_UTIL, instance)

패널 쿼리에서:
DCGM_FI_DEV_GPU_UTIL{instance="$instance"}
이러면 대시보드 상단에 노드 선택 드롭다운이 생기고, 선택한 노드의 GPU 메트릭만 보여줍니다
```
