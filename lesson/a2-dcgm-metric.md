## DCGM 메트릭 ##
### 네이밍 규칙 ###
DCGM_FI_DEV_<카테고리>_<세부항목>

```
DCGM_FI_DEV_FB_USED를 분해하면:

DCGM    _FI    _DEV    _FB       _USED
  │       │      │       │         │
  │       │      │       │         └─ 사용된 (Used)
  │       │      │       └─ Framebuffer (GPU 메모리 = HBM)
  │       │      └─ Device (GPU 디바이스)
  │       └─ Field ID (DCGM 메트릭 필드)
  └─ Data Center GPU Manager
```

### 주요 카테고리별 정리 ###

```
FB (Framebuffer) = GPU 메모리
DCGM_FI_DEV_FB_TOTAL        GPU 메모리 전체 용량 (MB)
DCGM_FI_DEV_FB_FREE         GPU 메모리 여유 (MB)
DCGM_FI_DEV_FB_USED         GPU 메모리 사용량 (MB)

GPU 활용률
DCGM_FI_DEV_GPU_UTIL        GPU SM 활용률 (%, 연산 유닛)
DCGM_FI_DEV_MEM_COPY_UTIL   메모리 대역폭 활용률 (%)
DCGM_FI_DEV_ENC_UTIL        인코더 활용률 (%)
DCGM_FI_DEV_DEC_UTIL        디코더 활용률 (%)

SM (Streaming Multiprocessor) = 연산 유닛
DCGM_FI_DEV_SM_CLOCK        SM 클럭 (MHz)
DCGM_FI_DEV_MEM_CLOCK       메모리 클럭 (MHz)
DCGM_FI_PROF_SM_ACTIVE      SM 활성 비율 (0~1)
DCGM_FI_PROF_SM_OCCUPANCY   SM 점유율 (0~1)

온도 / 전력
DCGM_FI_DEV_GPU_TEMP        GPU 코어 온도 (°C)
DCGM_FI_DEV_MEMORY_TEMP     HBM 메모리 온도 (°C)
DCGM_FI_DEV_POWER_USAGE     현재 전력 소비 (W)
DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION  누적 에너지 소비 (mJ)

Throttling (성능 제한)
DCGM_FI_DEV_THERMAL_VIOLATION      온도 throttling 발생 시간 (μs)
DCGM_FI_DEV_POWER_VIOLATION        전력 throttling 발생 시간 (μs)
DCGM_FI_DEV_BOARD_LIMIT_VIOLATION  보드 제한 throttling (μs)

ECC (에러 교정)
DCGM_FI_DEV_ECC_SBE_VOL_TOTAL     SBE 수 (현재 부팅 이후)
DCGM_FI_DEV_ECC_DBE_VOL_TOTAL     DBE 수 (현재 부팅 이후)
DCGM_FI_DEV_ECC_SBE_AGG_TOTAL     SBE 수 (전체 누적, 리셋 불가)
DCGM_FI_DEV_ECC_DBE_AGG_TOTAL     DBE 수 (전체 누적, 리셋 불가)
VOL = Volatile  (부팅 후 카운터, 리부팅하면 0으로 리셋)
AGG = Aggregate (GPU 수명 전체 누적, 리셋 안 됨)

Retired Pages / Row Remap
DCGM_FI_DEV_RETIRED_SBE           SBE로 retire된 페이지 수
DCGM_FI_DEV_RETIRED_DBE           DBE로 retire된 페이지 수
DCGM_FI_DEV_RETIRED_PENDING       retire 대기 중 (리부팅 필요)
DCGM_FI_DEV_ROW_REMAP_PENDING     row remap 대기 중

PCIe
DCGM_FI_DEV_PCIE_LINK_GEN         PCIe 세대 (4, 5 등)
DCGM_FI_DEV_PCIE_LINK_WIDTH       PCIe 레인 수 (16 등)
DCGM_FI_DEV_PCIE_TX_THROUGHPUT    PCIe 송신 throughput (KB/s)
DCGM_FI_DEV_PCIE_RX_THROUGHPUT    PCIe 수신 throughput (KB/s)
DCGM_FI_DEV_PCIE_REPLAY_COUNTER   PCIe 재전송 횟수 (증가하면 문제)

NVLink
DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL    NVLink 총 대역폭
DCGM_FI_DEV_NVLINK_CRC_FLIT_ERROR_COUNT_TOTAL  NVLink CRC 에러
DCGM_FI_DEV_NVLINK_CRC_DATA_ERROR_COUNT_TOTAL  NVLink 데이터 에러
DCGM_FI_DEV_NVLINK_REPLAY_ERROR_COUNT_TOTAL    NVLink 재전송 에러

Profiling (상세 성능)
DCGM_FI_PROF_GR_ENGINE_ACTIVE     그래픽 엔진 활성 비율
DCGM_FI_PROF_PIPE_TENSOR_ACTIVE   Tensor Core 활성 비율 (학습 효율 핵심)
DCGM_FI_PROF_PIPE_FP64_ACTIVE     FP64 파이프 활성 비율
DCGM_FI_PROF_PIPE_FP32_ACTIVE     FP32 파이프 활성 비율
DCGM_FI_PROF_PIPE_FP16_ACTIVE     FP16 파이프 활성 비율
DCGM_FI_PROF_DRAM_ACTIVE          HBM 활성 비율
DCGM_FI_PROF_PCIE_TX_BYTES        PCIe 송신 바이트
DCGM_FI_PROF_PCIE_RX_BYTES        PCIe 수신 바이트
DCGM_FI_PROF_NVLINK_TX_BYTES      NVLink 송신 바이트
DCGM_FI_PROF_NVLINK_RX_BYTES      NVLink 수신 바이트
```

### 주요 모니터링 항목 ###
```
# GPU가 일하고 있는지 (학습 효율)
DCGM_FI_PROF_PIPE_TENSOR_ACTIVE   # Tensor Core 사용률 → 높을수록 좋음

# GPU가 놀고 있는 이유 진단
DCGM_FI_DEV_GPU_UTIL == 0 and DCGM_FI_DEV_FB_USED > 0   # 좀비
DCGM_FI_DEV_GPU_UTIL < 50 and DCGM_FI_PROF_DRAM_ACTIVE > 0.8  # 메모리 병목
DCGM_FI_DEV_GPU_UTIL < 50 and DCGM_FI_PROF_DRAM_ACTIVE < 0.2  # 데이터 공급 부족

# 하드웨어 건강 상태
DCGM_FI_DEV_ECC_DBE_VOL_TOTAL > 0          # 즉시 교체
```
DCGM_FI_DEV_THERMAL_VIOLATION > 0           # 쿨링 문제
DCGM_FI_DEV_PCIE_REPLAY_COUNTER 증가        # PCIe 불안정
DCGM_FI_DEV_NVLINK_REPLAY_ERROR_COUNT_TOTAL 증가  # NVLink 불안정
