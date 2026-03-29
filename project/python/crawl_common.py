#!/usr/bin/env python3
"""
Common Crawl에서 한국어/영어 웹 데이터 추출
pip install warcio beautifulsoup4 fasttext langdetect
"""

import json
import gzip
import re
from io import BytesIO
from urllib.request import urlopen
from warcio.archiveiterator import ArchiveIterator
from bs4 import BeautifulSoup

# Common Crawl WARC 파일 목록 (2024-10 크롤)
# https://data.commoncrawl.org/crawl-data/CC-MAIN-2024-10/warc.paths.gz
WARC_URL = "https://data.commoncrawl.org/crawl-data/CC-MAIN-2024-10/segments/1707947473558.16/warc/CC-MAIN-20240217205423-20240217235423-00000.warc.gz"

def clean_html(html):
    """HTML에서 텍스트 추출"""
    soup = BeautifulSoup(html, 'html.parser')
    
    # 스크립트, 스타일 제거
    for tag in soup(['script', 'style', 'nav', 'header', 'footer', 'aside']):
        tag.decompose()
    
    text = soup.get_text(separator='\n')
    
    # 정제
    lines = [line.strip() for line in text.splitlines()]
    text = '\n'.join(line for line in lines if line)
    
    # 연속 공백 정리
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    return text.strip()

def is_quality(text, min_length=200, max_length=100000):
    """품질 필터"""
    if len(text) < min_length or len(text) > max_length:
        return False
    
    words = text.split()
    if len(words) < 50:
        return False
    
    # 반복 비율 체크 (스팸 필터)
    unique_ratio = len(set(words)) / len(words)
    if unique_ratio < 0.1:
        return False
    
    return True

def process_warc(warc_url, output_path, max_docs=10000):
    """WARC 파일에서 텍스트 추출"""
    print(f"Downloading: {warc_url}")
    response = urlopen(warc_url)
    stream = BytesIO(response.read())
    
    count = 0
    with open(output_path, 'w', encoding='utf-8') as f:
        for record in ArchiveIterator(stream):
            if record.rec_type != 'response':
                continue
            
            content_type = record.http_headers.get_header('Content-Type') or ''
            if 'text/html' not in content_type:
                continue
            
            try:
                html = record.content_stream().read().decode('utf-8', errors='ignore')
                text = clean_html(html)
                
                if is_quality(text):
                    f.write(json.dumps({"text": text}, ensure_ascii=False) + '\n')
                    count += 1
                    
                    if count % 100 == 0:
                        print(f"  {count} docs extracted")
                    
                    if count >= max_docs:
                        break
            except Exception:
                continue
    
    print(f"Done: {count} docs saved to {output_path}")

if __name__ == "__main__":
    process_warc(WARC_URL, "/fsx/data/commoncrawl.jsonl", max_docs=10000)
