## Parallelism 비교 ##
| 병렬화 | 통신 패턴 | 통신 빈도 | 메시지 크기 | 주요 병목 | 통신 위치 |
|--------|-----------|-----------|-------------|-----------|-----------|
| TP | All-Reduce | 레이어마다 2회 | 작음 (activation) | 레이턴시 | 노드 내 (NVLink) |
| SP | Reduce-Scatter + All-Gather | 레이어마다 2회 | 작음 (TP와 동일) | 레이턴시 | 노드 내 (NVLink) |
| PP | Point-to-Point | 스테이지 경계마다 | 중간 (activation) | 레이턴시 + 버블 | 노드 간 |
| DP | All-Reduce | 스텝마다 1회 | 큼 (전체 gradient) | 대역폭 | 노드 간 |
| FSDP | All-Gather + Reduce-Scatter | 레이어마다 | 큼 (파라미터) | 대역폭 | 노드 간 |
| EP | All-to-All | MoE 레이어마다 2회 | Expert 수에 따라 다름 | 대역폭 (+ 레이턴시) | 노드 간 |
| CP | Ring All-to-All | Attention마다 | 큼 (KV 텐서) | 대역폭 | 노드 간 |

정리하면:

* 레이턴시 민감:  TP, SP, PP  ← 작은 메시지를 자주 보냄
* 대역폭 민감:    DP, FSDP, EP, CP  ← 큰 메시지를 보냄
그래서 TP/SP는 NVLink(노드 내, 저레이턴시)에서 돌리고, DP/FSDP/EP는 InfiniBand/EFA(노드 간, 고대역폭)에서 돌리는 거예요. 네트워크 토폴로지 설계의 근거가 여기서 나옵니다.

### TP | All-Reduce | 레이어마다 2회 ###
```
Transformer 레이어 하나 안에 행렬 곱셈이 2번 있어요:
Transformer 레이어:

입력
 │
 ▼
[Attention]  ← 여기서 행렬 곱 → All-Reduce 1회
 │
 ▼
 LayerNorm
 │
 ▼
[MLP]        ← 여기서 행렬 곱 → All-Reduce 1회
 │
 ▼
 LayerNorm
 │
 ▼
출력

TP는 행렬 곱셈을 나누는 거니까, 행렬 곱이 끝날 때마다 결과를 합쳐야 합니다. Attention에서 1번, MLP에서 1번. 그래서 레이어당 2회.
Llama 8B가 32 레이어니까, forward pass에서 총 64번 All-Reduce가 발생합니다.
이게 TP가 레이턴시에 민감한 이유예요. 작은 메시지를 64번 보내니까요.
```

1 step(forward + backward) 기준으로 보면:
```
Forward:  32 레이어 × 2회 = 64회 All-Reduce
Backward: 32 레이어 × 2회 = 64회 All-Reduce
```
* 1 step 당 총 128회 All-Reduce (Llama 8B 기준)
* 배치 안에 샘플이 몇 개든 한번에 행렬 곱으로 처리하니까, 샘플 수와는 무관하고 step 당 횟수입니다.

## EP ##
### 일반 Transformer vs MoE Transformer ###
```
[일반 Transformer 레이어]
입력 → Attention → MLP → 출력
                    ↑
              하나의 큰 MLP (모든 토큰이 통과)


[MoE Transformer 레이어]
입력 → Attention → Router → Expert 1 (MLP)  → 출력
                     │       Expert 2 (MLP)
                     │       Expert 3 (MLP)
                     │       Expert 4 (MLP)
                     │       Expert 5 (MLP)
                     │       Expert 6 (MLP)
                     │       Expert 7 (MLP)
                     │       Expert 8 (MLP)
                     │
                     └→ 토큰마다 Top-K Expert 선택 (보통 K=2)
```
핵심: MLP를 여러 개(Expert)로 복제하고, Router가 토큰마다 "어떤 Expert를 쓸지" 결정합니다.

```
입력 → Attention → Router(토큰별 Expert 선택)
                      │
                      ▼ All-to-All (토큰을 Expert GPU로 전송)
                      │
              각 GPU에서 Expert 연산
                      │
                      ▼ All-to-All (결과를 원래 GPU로 반환)
                      │
                   → 출력
```
EP의 All-to-All이 네트워크에 가장 부담이 큽니다. 모든 GPU가 동시에 모든 GPU에게 데이터를 보내니까요. 그래서 DeepSeek, Mixtral 같은 MoE 모델을 학습할 때 네트워크 대역폭이 특히 중요해요.

메시지 자체가 큰 게 아니라, 동시에 모든 GPU가 보내니까 총 트래픽이 큰 거예요.
```
[TP: All-Reduce]
GPU 0 ↔ GPU 1    한 경로에서 통신
총 트래픽: 1 × 메시지 크기

[EP: All-to-All, GPU 4장]
GPU 0 → GPU 1, 2, 3    (3개 전송)
GPU 1 → GPU 0, 2, 3    (3개 전송)
GPU 2 → GPU 0, 1, 3    (3개 전송)
GPU 3 → GPU 0, 1, 2    (3개 전송)
총 트래픽: 12 × 메시지 크기    ← 네트워크에 동시에 쏟아짐
개별 메시지는 작을 수 있지만, N개 GPU가 동시에 N-1개씩 보내니까 네트워크 대역폭이 포화됩니다. 그래서 대역폭 병목이에요.

표에서 "Expert 수에 따라 다름"이라고 한 건:

Expert 적음 (8개): Expert당 토큰 많음 → 개별 메시지도 큼 → 대역폭 병목
Expert 많음 (256개): Expert당 토큰 적음 → 개별 메시지 작음 → 레이턴시도 병목
```


## TP (Tensor Parallem) ##
```
"나는 밥을 먹었다"
    │
    ▼ 토크나이저
[토큰1, 토큰2, 토큰3]
    │
    ▼ 임베딩 레이어
토큰1 = [0.12, -0.34, 0.56, ..., 0.78]  ← 이 벡터의 길이가 hidden_size
         ├──────── 4096개 (Llama 8B) ────┤
같은 말 다른 표현:

hidden_size = hidden_dim = d_model = 임베딩 차원 = 토큰의 dim
```

```
Y = X × W

X: 입력 (시퀀스 × 히든)
W: 가중치 (히든 × 히든)
Y: 출력 (시퀀스 × 히든)

입력 X (3토큰 × 4히든):          가중치 W (4히든 × 4히든):

     h0  h1  h2  h3                  h0  h1  h2  h3
t1 [ 1   2   3   4 ]           h0 [ 1   0   1   0 ]
t2 [ 5   6   7   8 ]           h1 [ 0   1   0   1 ]
t3 [ 9  10  11  12 ]           h2 [ 1   1   0   0 ]
                                h3 [ 0   0   1   1 ]
```

* GPU 1장에서 계산하면:
```
Y = X × W

t1: [1×1+2×0+3×1+4×0, 1×0+2×1+3×1+4×0, 1×1+2×0+3×0+4×1, 1×0+2×1+3×0+4×1]
   = [4, 5, 5, 6]

t2: [5×1+6×0+7×1+8×0, 5×0+6×1+7×1+8×0, 5×1+6×0+7×0+8×1, 5×0+6×1+7×0+8×1]
   = [12, 13, 13, 14]

t3: [9×1+10×0+11×1+12×0, 9×0+10×1+11×1+12×0, 9×1+10×0+11×0+12×1, 9×0+10×1+11×0+12×1]
   = [20, 21, 21, 22]

결과 Y:
     h0  h1  h2  h3
t1 [ 4   5   5   6 ]
t2 [ 12  13  13  14 ]
t3 [ 20  21  21  22 ]
```

### TP: 가중치 W를 열 방향으로 나눈다 ###
W를 반으로 쪼개서 GPU 2장에 나눠줍니다:
```
GPU 0: W₀ (왼쪽 2열)          GPU 1: W₁ (오른쪽 2열)

     h0  h1                        h2  h3
h0 [ 1   0 ]                 h0 [ 1   0 ]
h1 [ 0   1 ]                 h1 [ 0   1 ]
h2 [ 1   1 ]                 h2 [ 0   0 ]
h3 [ 0   0 ]                 h3 [ 1   1 ]
```

각 GPU에서 계산:
```
GPU 0: Y₀ = X × W₀ (3토큰 × 2히든)

t1: [1×1+2×0+3×1+4×0, 1×0+2×1+3×1+4×0] = [4, 5]
t2: [5×1+6×0+7×1+8×0, 5×0+6×1+7×1+8×0] = [12, 13]
t3: [9×1+10×0+11×1+12×0, 9×0+10×1+11×1+12×0] = [20, 21]

Y₀:
     h0  h1
t1 [ 4   5 ]
t2 [ 12  13 ]
t3 [ 20  21 ]


GPU 1: Y₁ = X × W₁ (3토큰 × 2히든)

t1: [1×1+2×0+3×0+4×1, 1×0+2×1+3×0+4×1] = [5, 6]
t2: [5×1+6×0+7×0+8×1, 5×0+6×1+7×0+8×1] = [13, 14]
t3: [9×1+10×0+11×0+12×1, 9×0+10×1+11×0+12×1] = [21, 22]

Y₁:
     h2  h3
t1 [ 5   6 ]
t2 [ 13  14 ]
t3 [ 21  22 ]
```

### 결과를 합치기: All-Gather ###
각 GPU가 가진 부분 결과를 모아서 전체를 만듭니다:
```
GPU 0의 Y₀:     GPU 1의 Y₁:
     h0  h1          h2  h3
t1 [ 4   5 ]   t1 [ 5   6 ]
t2 [ 12  13 ]   t2 [ 13  14 ]
t3 [ 20  21 ]   t3 [ 21  22 ]

         ↓ All-Gather (양쪽 조각을 합침)

두 GPU 모두 전체 결과를 갖게 됨:
     h0  h1  h2  h3
t1 [ 4   5   5   6 ]
t2 [ 12  13  13  14 ]
t3 [ 20  21  21  22 ]
```
### 정리 ###
```
[GPU 1장]
X(3×4) × W(4×4) = Y(3×4)

[GPU 2장, TP=2]
GPU 0: X(3×4) × W₀(4×2) = Y₀(3×2)  ← 가중치 절반, 결과도 절반
GPU 1: X(3×4) × W₁(4×2) = Y₁(3×2)  ← 가중치 절반, 결과도 절반
                    ↓
              All-Gather → Y(3×4)    ← 합치면 원래 결과
```
* 입력 X는 모든 GPU에 전체 복사 (시퀀스 전체)
* 가중치 W만 나눔 (히든 방향으로)
* 각 GPU의 연산량과 메모리가 절반으로 줄어듦
* 대신 All-Gather 통신이 필요 → NVLink가 빠르니까 노드 내에서만 사용
  
## SP (Sequence Parallel) ##
핵심은 "TP에서 입력 X가 모든 GPU에 전체 복사되는 게 낭비니까, X도 토큰 방향으로 나누자"...

TP 결과 복습
```
GPU 0: Y₀ (3토큰 × 2히든)     GPU 1: Y₁ (3토큰 × 2히든)

     h0  h1                        h2  h3
t1 [ 4   5 ]                 t1 [ 5   6 ]
t2 [ 12  13 ]                t2 [ 13  14 ]
t3 [ 20  21 ]                t3 [ 21  22 ]
이제 이 부분 결과를 합쳐야 하는데, 여기서 갈림길이 생깁니다.

TP만 쓸 때: All-Reduce

All-Gather로 양쪽 결과를 합침 → 모든 GPU가 전체를 가짐

GPU 0:                          GPU 1:
     h0  h1  h2  h3                 h0  h1  h2  h3
t1 [ 4   5   5   6 ]          t1 [ 4   5   5   6 ]     ← 동일!
t2 [ 12  13  13  14 ]         t2 [ 12  13  13  14 ]     ← 동일!
t3 [ 20  21  21  22 ]         t3 [ 20  21  21  22 ]     ← 동일!

     ↓ LayerNorm                    ↓ LayerNorm
     3토큰 전부 처리                  3토큰 전부 처리      ← 중복 연산 + 중복 메모리
```

### TP + SP 쓸 때: Reduce-Scatter ###
All-Gather 대신 Reduce-Scatter를 씁니다. 합친 결과를 전체 복사하지 않고, 토큰별로 나눠서 분배:

```
Reduce-Scatter: 합치되, 조각으로 나눠서 분배

GPU 0: t1, t2만 받음            GPU 1: t3만 받음

     h0  h1  h2  h3                 h0  h1  h2  h3
t1 [ 4   5   5   6 ]          t3 [ 20  21  21  22 ]
t2 [ 12  13  13  14 ]

     ↓ LayerNorm                    ↓ LayerNorm
     2토큰만 처리                     1토큰만 처리        ← 메모리 절약!

     ↓ Dropout                      ↓ Dropout
     2토큰만 처리                     1토큰만 처리        ← 메모리 절약!
```
다음 Attention으로 넘어갈 때: All-Gather
Attention은 전체 시퀀스가 필요하니까, 다시 모아야 합니다:
```
GPU 0: t1, t2                  GPU 1: t3

     ↓ All-Gather (조각을 모아서 전체로)

GPU 0:                          GPU 1:
     h0  h1  h2  h3                 h0  h1  h2  h3
t1 [ 4   5   5   6 ]          t1 [ 4   5   5   6 ]
t2 [ 12  13  13  14 ]         t2 [ 12  13  13  14 ]
t3 [ 20  21  21  22 ]         t3 [ 20  21  21  22 ]

     ↓ Attention (TP)               ↓ Attention (TP)

     ↓ Reduce-Scatter (다시 조각으로)

GPU 0: t1, t2                  GPU 1: t3

     ↓ LayerNorm (SP)               ↓ LayerNorm (SP)

     ... 반복
```

### 전체 흐름 비교 ###
```
[TP만]
Attention → All-Gather → [3토큰 전체] → LayerNorm [3토큰] → Dropout [3토큰] → 다음 Attention
                          GPU당 3토큰    GPU당 3토큰          GPU당 3토큰

[TP+SP]
Attention → Reduce-Scatter → [1~2토큰] → LayerNorm [1~2토큰] → Dropout [1~2토큰] → All-Gather → 다음 Attention
                              GPU당 1~2토큰  GPU당 1~2토큰       GPU당 1~2토큰
```
통신량은 동일해요:
* All-Reduce = Reduce-Scatter + All-Gather
* SP는 이 하나의 통신을 두 단계로 쪼개서, 그 사이 구간(LayerNorm, Dropout)에서 메모리를 아끼는 겁니다

