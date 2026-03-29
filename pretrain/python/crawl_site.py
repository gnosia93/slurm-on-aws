#!/usr/bin/env python3
"""
사이트 크롤링
pip install requests beautifulsoup4 trafilatura
"""

import json
import time
import trafilatura
from urllib.parse import urljoin
import requests
from bs4 import BeautifulSoup

def crawl_site(base_url, max_pages=500, output_path="crawled.jsonl"):
    """사이트 크롤링"""
    visited = set()
    to_visit = [base_url]
    docs = []
    
    while to_visit and len(visited) < max_pages:
        url = to_visit.pop(0)
        if url in visited:
            continue
        
        try:
            # robots.txt 존중
            time.sleep(1)  # 1초 대기 (예의)
            
            response = requests.get(url, timeout=10, headers={
                'User-Agent': 'Mozilla/5.0 (research crawler)'
            })
            
            if response.status_code != 200:
                continue
            
            visited.add(url)
            
            # trafilatura로 본문 추출 (광고/네비게이션 자동 제거)
            text = trafilatura.extract(response.text)
            
            if text and len(text) > 200:
                docs.append({"text": text, "url": url})
                print(f"[{len(docs)}] {url[:80]}")
            
            # 링크 수집 (같은 도메인만)
            soup = BeautifulSoup(response.text, 'html.parser')
            for link in soup.find_all('a', href=True):
                next_url = urljoin(base_url, link['href'])
                if next_url.startswith(base_url) and next_url not in visited:
                    to_visit.append(next_url)
        
        except Exception as e:
            continue
    
    # JSONL 저장
    with open(output_path, 'w', encoding='utf-8') as f:
        for doc in docs:
            f.write(json.dumps(doc, ensure_ascii=False) + '\n')
    
    print(f"\nDone: {len(docs)} docs saved")

if __name__ == "__main__":
    crawl_site(
        base_url="https://ko.wikipedia.org/wiki/",
        max_pages=1000,
        output_path="/fsx/data/wiki_crawl.jsonl"
    )
