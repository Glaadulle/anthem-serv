# Usage : gdb -p PID -batch -x tools/gdb_exit.gdb : à la fin du processus (appels système exit_group et exit d'un fil), note dans data/exit.txt le fil, rip et les adresses de code d'Anthem.exe dans sa pile, pour retrouver qui ferme le jeu.
set pagination off
set confirm off
handle SIGSEGV nostop noprint pass
handle SIGBUS nostop noprint pass
handle SIGILL nostop noprint pass
handle SIGFPE nostop noprint pass
handle SIGUSR1 nostop noprint pass
handle SIGUSR2 nostop noprint pass
handle SIGPIPE nostop noprint pass
handle SIGALRM nostop noprint pass
handle SIGQUIT nostop noprint pass
catch syscall exit_group
python
import gdb
import struct
import time

CODE_START, CODE_END = 0x140001000, 0x154000000
STACK_BYTES = 0x8000
inferior = gdb.selected_inferior()


def register(name):
    return int(gdb.parse_and_eval("$" + name)) & 0xFFFFFFFFFFFFFFFF


def stop_handler(event):
    thread = gdb.selected_thread()
    rsp = register("rsp")
    try:
        stack = bytes(inferior.read_memory(rsp, STACK_BYTES))
    except gdb.MemoryError:
        stack = b""
    words = struct.unpack(f"<{len(stack) // 8}Q", stack)
    code = " ".join(f"{offset * 8:#x}:{word:#x}" for offset, word in enumerate(words) if CODE_START <= word < CODE_END)
    with open("data/exit.txt", "a") as log:
        log.write(f"{time.strftime('%H:%M:%S')} fil {thread.num} {thread.name} rip {register('rip'):#x} pile {code}\n")


gdb.events.stop.connect(stop_handler)
end
continue
continue
