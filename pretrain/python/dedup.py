#!/usr/bin/env python3
"""
MinHash 기반 유사 문서 중복 제거
pip install datasketch
"""

import json
from datasketch import MinHash, MinHashLSH

def dedup_jsonl(input_path, output_path, threshold=0.8):
    """유사도 80% 이상 문서 제거"""
    lsh = MinHashLSH(threshold=threshold, num_perm=128)
    
    total = 0
    kept = 0
    
    with open(input_path, 'r') as fin, open(output_path, 'w') as fout:
        for line in fin:
            total += 1
            doc = json.loads(line)
            text = doc['text']
            
            # MinHash 생성
            m = MinHash(num_perm=128)
            for word in text.split():
                m.update(word.encode('utf-8'))
            
            # 유사 문서 있는지 확인
            if not lsh.query(m):
                lsh.insert(str(total), m)
                fout.write(line)
                kept += 1
            
            if total % 1000 == 0:
                print(f"  {total} processed, {kept} kept ({kept/total*100:.1f}%)")
    
    print(f"\nDone: {total} → {kept} ({total-kept} duplicates removed)")

if __name__ == "__main__":
    dedup_jsonl("/fsx/data/commoncrawl.jsonl", "/fsx/data/commoncrawl_dedup.jsonl")
