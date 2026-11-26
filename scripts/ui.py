#!/usr/bin/env python3
"""UI helper for emulator tests. Usage: ui.py dump OUTDIR NAME | tap-text TEXT | tap-checkables | tap-xy X Y | texts"""
import subprocess, sys, re, xml.etree.ElementTree as ET

def adb(*a):
    return subprocess.run(['adb', *a], capture_output=True, text=True).stdout

def dump():
    adb('shell', 'uiautomator', 'dump', '/sdcard/ui.xml')
    x = adb('exec-out', 'cat', '/sdcard/ui.xml')
    try:
        return ET.fromstring(x)
    except Exception:
        return None

def center(b):
    m = re.findall(r'\d+', b)
    l, t, r, bt = map(int, m)
    return (l + r) // 2, (t + bt) // 2

def nodes(root):
    return [n for n in root.iter('node')] if root is not None else []

def texts(root):
    out = []
    for n in nodes(root):
        t = n.get('text') or n.get('content-desc')
        if t:
            out.append(t.replace('\n', ' '))
    return out

def tap(x, y):
    adb('shell', 'input', 'tap', str(x), str(y))

if __name__ == '__main__':
    cmd = sys.argv[1]
    root = dump()
    if cmd == 'texts':
        print(' | '.join(texts(root)))
    elif cmd == 'tap-text':
        want = sys.argv[2].lower()
        for n in nodes(root):
            t = (n.get('text') or n.get('content-desc') or '').lower()
            if t == want or (len(sys.argv) > 3 and want in t):
                tap(*center(n.get('bounds'))); print('tapped', t); sys.exit(0)
        print('notfound', want); sys.exit(1)
    elif cmd == 'tap-checkables':
        c = 0
        for n in nodes(root):
            if n.get('checkable') == 'true' and n.get('checked') == 'false':
                tap(*center(n.get('bounds'))); c += 1
        print('checked', c)
    elif cmd == 'tap-class':
        c = 0
        for n in nodes(root):
            if n.get('class', '').endswith(sys.argv[2]):
                tap(*center(n.get('bounds'))); c += 1
        print('tapped', c)
    elif cmd == 'clickables':
        print(' | '.join((n.get('text') or n.get('content-desc') or n.get('class').split('.')[-1]) + '@' + n.get('bounds') for n in nodes(root) if n.get('clickable') == 'true'))
    elif cmd == 'tap-xy':
        tap(sys.argv[2], sys.argv[3])
