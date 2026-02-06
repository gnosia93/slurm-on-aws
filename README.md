# slurm-on-aws

* [C1. VPC 생성하기](https://github.com/gnosia93/slurm-on-aws/blob/main/tf/readme.md)

* [C2. slurm 설치하기](https://github.com/gnosia93/slurm-on-aws/tree/main/ansible)

- 이미지 100만장 처리하는 워크로드 / CPU 로 처리한다.
- 이미지 처리 로직은 무엇으로 할까?... 리사이즈 ? 디텍션 ? Crop ? 
- 이미지 데이터는 S3 에 저장한 후 --> NVME 가 있는 로컬 디스크로 복사한다. --> 처리 완료후 다시 S3 로 저장.. 
- 1차적으로 CPU 처리
- 2차적으로 부수적으로 GPU 처리..
