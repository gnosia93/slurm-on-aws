```
/home (ZFS - Zetta):
  - 소스 코드, 설정 파일, 스크립트
  - 용량 작고, I/O 적음
  - 스냅샷으로 실수 복구 가능
  - 사용자별 환경 관리

/scratch 또는 /fsx (Lustre):
  - 학습 데이터셋 (수 TB)
  - 체크포인트 (수십~수백 GB)
  - 수백 GPU가 동시에 읽기/쓰기
  - 초고속 I/O 필요
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/9-shared-fs.md)
