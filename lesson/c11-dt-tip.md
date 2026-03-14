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
* GPU 메모리 ECC(Error Correcting Code) 에러 → 자동 재계산으로 느려짐
  * SBE (Single-Bit Error): ECC가 감지하고 자동 교정까지 완료. 
  * DBE (Double-Bit Error): ECC가 감지는 했지만 교정 불가. --> GPU 교체

### lustre ###
