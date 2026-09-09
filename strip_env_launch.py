"""Launch a process with bash's hidden drive-relative cwd vars (=E: etc.)
stripped — gomobile v0.1.13 panics on them (audit note: env.go:518)."""
import ctypes, subprocess, sys

k32 = ctypes.WinDLL('kernel32', use_last_error=True)

def strip_drive_cwd_vars():
    block = k32.GetEnvironmentStringsW()
    if not block:
        return []
    removed = []
    pos = block
    deleted = set()
    while True:
        # entry: null-terminated "NAME=VALUE"; double-null ends the block
        end = pos
        while ctypes.cast(end, ctypes.c_wchar_p).value != '':
            end += 2  # wchar_t is 2 bytes
            if end.value == 0:
                break
        entry = ctypes.cast(pos, ctypes.c_wchar_p).value or ''
        if not entry:
            break
        pos = ctypes.addressof(ctypes.c_char.from_address(pos))  # noop guard
        # advance properly via pointer arithmetic on the original pointer
        nxt = pos
        while ctypes.c_wchar.from_address(nxt).value != '\x00':
            nxt += 2
        entry = ''.join(
            ctypes.c_wchar.from_address(pos + i * 2).value
            for i in range((nxt - pos) // 2)
        )
        nxt += 2  # skip terminator
        if entry == '':
            break
        if entry.startswith('='):
            name = entry.split('=', 1)[0]
            if ctypes.windll.kernel32.SetEnvironmentVariableW(name, None):
                removed.append(name)
        pos = nxt
    k32.FreeEnvironmentStringsW(block)
    return removed

removed = strip_drive_cwd_vars()
print('stripped:', removed)
sys.exit(subprocess.call(sys.argv[1:]))
