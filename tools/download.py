"""Download files with resume support using only stdlib (OpenSSL-backed)."""
import sys, os, urllib.request, time

def download(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    headers = {"User-Agent": "Mozilla/5.0 (AincradProto builder)"}
    start = 0
    if os.path.exists(dest):
        start = os.path.getsize(dest)
        if start > 0:
            headers["Range"] = f"bytes={start}-"
    req = urllib.request.Request(url, headers=headers)
    total = None
    last = time.time()
    done = 0
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                if start > 0 and resp.status != 206:
                    start = 0
                    done = 0
                length = resp.headers.get("Content-Length")
                if length:
                    total = start + int(length)
                mode = "ab" if start > 0 and done == 0 else "ab"
                with open(dest, mode) as f:
                    while True:
                        chunk = resp.read(1 << 20)
                        if not chunk:
                            break
                        f.write(chunk)
                        done += len(chunk)
                        if time.time() - last > 5:
                            if total:
                                print(f"  {done}/{total} ({100*done/total:.1f}%)", flush=True)
                            last = time.time()
            print(f"OK {dest} ({done} bytes)", flush=True)
            return 0
        except Exception as e:
            print(f"attempt {attempt+1} failed: {e}", flush=True)
            time.sleep(5)
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Range": f"bytes={done}-"} if done > 0 else {})
    print(f"FAILED {url}", flush=True)
    return 1

if __name__ == "__main__":
    rc = 0
    for i in range(1, len(sys.argv), 2):
        rc |= download(sys.argv[i], sys.argv[i+1])
    sys.exit(rc)
