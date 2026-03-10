
## [pcluster 설치하기](https://pypi.org/project/aws-parallelcluster/) ## 
```
sudo dnf install python3-pip -y

pip install aws-parallelcluster
pcluster version
```
[결과]
```
{
  "version": "3.14.2"
}
```

## 클러스터 생성하기 ##


[INFO] PRIVATE_SUBNET_ID = subnet-01f8afc98139cfb4f
[INFO] PUBLIC_SUBNET_ID = subnet-0150810abf7d58f5c
[INFO] FSX_ID = fs-0cfc8084593407ace
[INFO] FSX_MOUNTNAME = obmixbev
[INFO] FSXO_ID = fsvol-0be57cf3806xxxxx
[INFO] SECURITY_GROUP = sg-094ac36f5e082cf86

```bash
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)

echo $AWS_REGION
echo $AWS_ACCOUNT_ID
echo $VPC_ID
```

## 레퍼런스 ##

* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US
