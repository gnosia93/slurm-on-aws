## pretrain ##

![](https://github.com/gnosia93/slurm-on-aws/blob/main/pretrain/pipeline.png)
* 토크나이저 선택
  * → 한국어면 SentencePiece 기반 다국어 토크나이저
  * → vocab size가 크면 한국어 효율 좋음 (128K+)

### 1. 데이터 수집 ###
```
웹 크롤링:
  Common Crawl (가장 큰 공개 웹 데이터, 페타바이트급)
  → https://commoncrawl.org
  → WARC 파일 형태로 제공

공개 데이터셋:
  The Pile (825GB, 22개 소스, GPT-NeoX/Pythia 학습에 사용)
  RedPajama (1.2T 토큰, Llama 재현 목적)
  FineWeb (15T 토큰, HuggingFace 제공)
  Wikipedia (다국어 백과사전)
  arXiv (논문)
  GitHub (코드)
  Books3 (도서)

한국어:
  나무위키 덤프
  한국어 위키피디아
  AI Hub 데이터셋 (정부 제공)
  뉴스 크롤링 (저작권 주의)
  모두의 말뭉치 (국립국어원)
```


#### HuggingFace 다운로드 예시 ####
```
pip install datasets

python -c "
from datasets import load_dataset

# Wikipedia
ds = load_dataset('wikipedia', '20220301.en', split='train')
ds.to_json('/fsx/data/wiki.jsonl', lines=True)

# The Pile (일부)
ds = load_dataset('EleutherAI/pile', split='train', streaming=True)

# FineWeb
ds = load_dataset('HuggingFaceFW/fineweb', split='train', streaming=True)

# 한국어 위키
ds = load_dataset('wikipedia', '20220301.ko', split='train')
"
```

### 2. 데이터 정제 (Cleaning) ###
```
1. 중복 제거 (Deduplication)
   - 정확 중복: 해시 기반 (SHA-256)
   - 유사 중복: MinHash + LSH (가장 중요)
   → 중복 데이터는 학습 품질을 떨어뜨림

2. 품질 필터링
   - 언어 감지 (fasttext lid.176.bin)
   - perplexity 기반 필터 (KenLM)
   - 욕설/유해 콘텐츠 필터
   - 광고/스팸 제거

3. PII 제거
   - 이메일, 전화번호, 주소 마스킹
   - 이름, 주민번호 등 개인정보 제거

4. 포맷 정규화
   - 인코딩 통일 (UTF-8)
   - 줄바꿈 통일
   - 특수문자 정규화
```



```
# 기본 정제 파이프라인
def clean_text(text):
    # 1. HTML 태그 제거
    text = re.sub(r'<[^>]+>', '', text)
    
    # 2. 특수문자/이상한 유니코드 제거
    text = text.encode('utf-8', errors='ignore').decode('utf-8')
    
    # 3. 연속 공백/줄바꿈 정리
    text = re.sub(r'\s+', ' ', text).strip()
    
    # 4. 너무 짧은 문서 제거 (의미 없음)
    if len(text) < 100:
        return None
    
    # 5. 너무 긴 반복 패턴 제거 (스팸)
    if len(set(text.split())) / len(text.split()) < 0.1:
        return None
    
    return text
```

#### 중복 제거 도구 ####
```
# MinHash 기반 중복 제거 (가장 많이 쓰임)
pip install datasketch

# 또는 deduplicate-text-datasets (Google 제공)
pip install deduplicate-text-datasets


# MinHash 중복 제거 예시
from datasketch import MinHash, MinHashLSH

lsh = MinHashLSH(threshold=0.8, num_perm=128)

for doc_id, text in enumerate(documents):
    m = MinHash(num_perm=128)
    for word in text.split():
        m.update(word.encode('utf-8'))
    
    # 유사 문서 있으면 제거
    if not lsh.query(m):
        lsh.insert(doc_id, m)
        clean_docs.append(text)
```

        
### 3. JSONL 포맷으로 변환 ###
```
import json

# Megatron-LM이 기대하는 포맷
# 한 줄에 하나의 JSON, "text" 필드 필수
with open('training_data.jsonl', 'w') as f:
    for doc in clean_docs:
        f.write(json.dumps({"text": doc}, ensure_ascii=False) + '\n')
{"text": "첫 번째 문서 내용..."}
{"text": "두 번째 문서 내용..."}
{"text": "세 번째 문서 내용..."}
```

### 4. 토크나이징 + 바이너리 변환 ###
```
# Megatron-LM 포맷으로 변환
cd Megatron-LM

python tools/preprocess_data.py \
  --input /fsx/data/training_data.jsonl \
  --output-prefix /fsx/data/my-dataset \
  --tokenizer-type GPTSentencePieceTokenizer \
  --tokenizer-model /path/to/tokenizer.model \
  --workers 32 \
  --append-eod

# 결과:
# /fsx/data/my-dataset_text_document.bin (토큰 바이너리)
# /fsx/data/my-dataset_text_document.idx (인덱스)
```

#### 토크나이저 ####
한국어를 지원하는 Llama 토크나이저를 사용한다.  
HuggingFace에서 tokenizer.model 을 다운로드 한다. (HF_TOKEN 필요)
```
python tools/preprocess_data.py \
  --input /fsx/data/wiki_all.jsonl \
  --output-prefix /fsx/data/wiki \
  --tokenizer-type GPTSentencePieceTokenizer \
  --tokenizer-model /fsx/models/llama/tokenizer.model \
  --workers 32 \
  --append-eod
```

### 5. sbatch 훈련 ###
```
# gpt-70b.sh에서 mock-data 관련 줄 교체
# 제거:
    --mock-data \
    --vocab-size 32000 \
    --tokenizer-type NullTokenizer \

# 추가:
    --data-path /fsx/data/wiki_text_document \
    --tokenizer-type GPTSentencePieceTokenizer \
    --tokenizer-model /fsx/models/llama/tokenizer.model \
```
