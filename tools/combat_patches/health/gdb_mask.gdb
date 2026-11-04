set pagination off
set confirm off
handle all nostop noprint pass
python
import gdb, struct, time, collections
LOG = "/tmp/claude-1000/combat/health/mask.txt"
DUREE = 120
inf = gdb.selected_inferior()
counts = collections.Counter()
t0 = time.time(); last = [time.time()]
def reg(n): return int(gdb.parse_and_eval("$" + n)) & 0xFFFFFFFFFFFFFFFF
def pile():
    raw = bytes(inf.read_memory(reg("rsp"), 0x200)); out = []
    for i in range(0, 0x200, 8):
        v = struct.unpack_from("<Q", raw, i)[0]
        if 0x140001000 <= v < 0x153700000:
            out.append(f"{v:#x}")
            if len(out) == 6: break
    return ",".join(out)
class P(gdb.Breakpoint):
    def __init__(self):
        super().__init__("*0x140C7D440", type=gdb.BP_HARDWARE_BREAKPOINT)
    def stop(self):
        try:
            counts[f"ecriture_sante this={reg('rcx'):#x} masque={reg('rdx') & 0xffffffff:#x} pile={pile()}"] += 1
        except gdb.MemoryError:
            counts["illisible"] += 1
        if counts and time.time() - last[0] > 2:
            with open(LOG, "a") as h:
                h.write(time.strftime('%H:%M:%S') + " " + " | ".join(f"{k} x{v}" for k, v in sorted(counts.items())) + "\n")
            counts.clear(); last[0] = time.time()
        if time.time() - t0 > DUREE:
            self.enabled = False
            gdb.post_event(lambda: gdb.execute("detach"))
        return False
with open(LOG, "a") as h: h.write(time.strftime('%H:%M:%S') + " attaché\n")
P()
end
continue
