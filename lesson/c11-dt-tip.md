### 좀비 프로세스 ###

### OOM 방지 ###

## Staggler 노드 detection ##

### Straggler가 발생하는 원인 ###
* GPU 하드웨어 열화 (메모리 에러, 클럭 다운)
* NVLink/EFA 네트워크 성능 저하
* 특정 노드의 스토리지 I/O 병목 (Lustre OST 불균형 등)
* CPU throttling (온도, 전력)
* 백그라운드 프로세스 (OS 업데이트, 로그 수집 등)
* NCCL 통신 경로 이슈


#### GPU 메모리 ECC(Error Correcting Code) 에러 ####
```
• SBE (Single-Bit Error): ECC가 감지하고 자동 교정 → 빈발 시 오버헤드 누적으로 느려짐
• DBE (Double-Bit Error): ECC가 감지하지만 교정 불가 → 데이터 손상
  ├── 경우 1: 페이지 retire + XID 63 → 프로세스 크래시 → 체크포인트에서 재시작
  └── 경우 2: XID 48 → GPU 크래시 → GPU 교체
```

### lustre ###
