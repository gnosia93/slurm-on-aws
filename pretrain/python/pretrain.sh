# 1. 데이터 수집
# python crawl_commoncrawl.py
python crawl_site.py

# 2. 중복 제거
python dedup.py

# 3. Megatron-LM 포맷 변환
cd ~/Megatron-LM
python tools/preprocess_data.py \
  --input /fsx/data/commoncrawl_dedup.jsonl \
  --output-prefix /fsx/data/my-dataset \
  --tokenizer-type GPTSentencePieceTokenizer \
  --tokenizer-model /fsx/models/llama/tokenizer.model \
  --workers 32 \
  --append-eod

# 4. 학습
sbatch gpt-70b.sh
