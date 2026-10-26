# -*- coding: utf-8 -*-
"""Parallel segmented downloader with per-segment resume (works around per-connection throttling)."""
import os, sys, threading, urllib.request, time, ssl

CTX = ssl._create_unverified_context()

def head(url):
    req = urllib.request.Request(url, method="GET", headers={"User-Agent": "Mozilla/5.0", "Range": "bytes=0-0"})
    try:
        with urllib.request.urlopen(req, timeout=20, context=CTX) as r:
            cr = r.headers.get("Content-Range") or ""
            if cr and "/" in cr:
                return int(cr.rsplit("/", 1)[1]), r.status
            return int(r.headers.get("Content-Length") or 0), r.status
    except Exception as e:
        return 0, str(e)

def download_segment(url, start, end, path, prog, lock, results):
    headers = {"User-Agent": "Mozilla/5.0", "Range": f"bytes={start}-{end}"}
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=60, context=CTX) as r:
                with open(path, "r+b") as f:
                    f.seek(start)
                    got = start
                    while True:
                        chunk = r.read(1 << 18)
                        if not chunk:
                            break
                        f.write(chunk)
                        got += len(chunk)
                        with lock:
                            prog[0] += len(chunk)
            results.append((start, end, True))
            return
        except Exception as e:
            time.sleep(3 + attempt * 3)
    results.append((start, end, False))

def parallel_download(url, dest, parts=8):
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    total, st = head(url)
    if not total:
        print(f"HEAD failed ({st}); falling back to single stream", flush=True)
        return 1
    if not os.path.exists(dest):
        with open(dest, "wb") as f:
            f.truncate(total)
    size = total
    seg = (size + parts - 1) // parts
    lock = threading.Lock()
    prog = [0]
    results = []
    ts = []
    t0 = time.time()
    for i in range(parts):
        s = i * seg
        if s >= size:
            break
        e = min(s + seg - 1, size - 1)
        t = threading.Thread(target=download_segment, args=(url, s, e, dest, prog, lock, results), daemon=True)
        t.start()
        ts.append(t)
    def report():
        while any(t.is_alive() for t in ts):
            time.sleep(5)
            print(f"  {prog[0]/1048576:.1f}/{size/1048576:.1f} MB ({100*prog[0]/size:.1f}%) {(prog[0]/1048576)/max(1,(time.time()-t0)):.2f} MB/s", flush=True)
    rep = threading.Thread(target=report, daemon=True)
    rep.start()
    for t in ts:
        t.join()
    ok = all(r[2] for r in results)
    print(f"{'OK' if ok else 'PARTIAL'} {dest} {prog[0]/1048576:.1f} MB ({time.time()-t0:.0f}s)", flush=True)
    return 0 if ok else 1

if __name__ == "__main__":
    rc = 0
    for i in range(1, len(sys.argv), 2):
        rc |= parallel_download(sys.argv[i], sys.argv[i+1])
    sys.exit(rc)
