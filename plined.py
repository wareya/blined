#!/usr/bin/env python3

import os
import sys
import termios
import fcntl
import select
import time
import tty
import signal

def main():
    def disable_stdin_echo():
        os.system("stty -ixon")
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            new_settings = old_settings[:]
            new_settings[3] = new_settings[3] & ~termios.ECHO
            new_settings[1] = new_settings[1] & ~termios.IXON
            termios.tcsetattr(fd, termios.TCSADRAIN, new_settings)
        except: pass
        return old_settings

    def restore_stdin_echo(old_settings):
        os.system("stty ixon")
        fd = sys.stdin.fileno()
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

    fd = sys.stdin.fileno()
    flags = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
    
    old_settings = disable_stdin_echo()
    
    fname = sys.argv[1] if len(sys.argv) > 1 else None
    flag = sys.argv[2] if len(sys.argv) > 2 else None

    if not fname:
        print("Usage: python3 plined.py <filename> [-s]")
        return

    if not os.path.exists(fname):
        print(f"No such file `{fname}`, create it first with `touch {fname}` or `echo '' > {fname}`.")
        return

    lf = '\n'
    lines = []

    with open(fname, 'r') as f:
        for line in f:
            if '\r' in line:
                lf = '\r\n'
            lines.append(line.rstrip('\n').rstrip('\r'))

    if flag != '-s':
        print("Welcome to \033[32mplined\033[0m, the pure Python line-based text editor!")
        print("This is an \033[32minsertion mode\033[0m text editor: you move around with arrow keys and start typing.")
        print("Home, end, pgup, pgdn, backspace, and del should work. If not, please open a bug report.")
        print("plined is mainly meant for \033[30m\033[41memergency usage\033[0m, and lacks most common text editor features.")
        print("Ctrl+o will save the file \033[30m\033[41mimmediately\033[0m, with no prompt or warning.")
        print("Key combinations other than ctrl+o are \033[30m\033[41mnot supported\033[0m. Use ctrl+c to exit.")
        print("")
        print(f"You are currently editing:\n{fname}")
        print("")

    secs = 0
    row = 0
    col = 0
    colmem = 0
    offs = 0
    info = ""
    columns = 72

    def clear():
        print("\033[2K\r", end='')

    def printify(pfrow, pfcol):
        nonlocal info
        nonlocal line
        nonlocal secs
        if secs != time.time():
            secs = time.time()
            columns = os.get_terminal_size().columns

        info = f'(line {pfrow+1})'
        line = lines[pfrow]

        line = line[offs:columns - len(info) - 1]
        print(f"\033[2K\r\033[90m{info}\033[0m{line}\033[{len(info)+col+1-offs}G", end='', flush=True)

    def dodel():
        nonlocal col, row, lines
        line = lines[row]
        if col < len(line):
            line = line[:col] + line[col + 1:]
            lines[row] = line
        elif row + 1 < len(lines):
            line1 = lines[row]
            line2 = lines[row + 1]
            lines[row] = line1 + line2
            lines.pop(row + 1)
            col = len(line1)
            colmem = col

    def charkind(c):
        if c == "":
            return 2
        cv = ord(c)
        if 0x30 <= cv <= 0x39 or 0x41 <= cv <= 0x5A or 0x61 <= cv <= 0x7A or cv > 0x7F:
            return 0
        elif cv >= 0x21:
            return 1
        else:
            return 2

    rawdata = ""
    def read_input(n, timeout=0.01):
        nonlocal rawdata
        start_time = time.time()
        data = ""
        
        if rawdata != "":
            while len(data) < n and rawdata != "":
                data += rawdata[0]
                rawdata = rawdata[1:]
            if len(data) == n:
                return data
        
        while len(rawdata) < n and timeout - (time.time() - start_time) > 0:
            r, _, _ = select.select([sys.stdin], [], [], timeout - (time.time() - start_time))
            if r:
                rawdata += sys.stdin.read()
        
        if rawdata != "":
            while len(data) < n and rawdata != "":
                data += rawdata[0]
                rawdata = rawdata[1:]
            if len(data) == n:
                return data
        
        return rawdata

    def read_single_char():
        c = read_input(1)
        while c == "":
            c = read_input(1)
        return c
    
    try:
        printify(0, 0)

        while True:
            key = read_single_char()
            
            startcol = col
            startrow = row
            if key == '\x1b': # Escape sequence
                pfkey = read_input(1)
                key = read_input(1)
                fullkey = pfkey + key
                unk = 0
                if pfkey == "O" or pfkey == "[":
                    if key == "3":  # delete
                        dodel()
                    elif key == "5":  # pgdn
                        row -= 50
                    elif key == "6":  # pgup
                        row += 50
                    elif key == "A":  # up
                        row -= 1
                    elif key == "B":  # down
                        row += 1
                    elif key == "C":  # right
                        col += 1
                    elif key == "D":  # left
                        col -= 1
                    elif key == "F" or key == "4":  # end
                        col = len(lines[row])
                    else:
                        unk = 1
                else:
                    unk = 1
                if fullkey == "[H" or fullkey == "OH" or fullkey == "O1":
                    col = 0
                    unk = 0
                if unk == 1:
                    if fullkey == "[1" or fullkey == '\x1b[' or fullkey == "OC" or fullkey == "OD":
                        nukey = read_input(3)
                        if nukey == "~":
                            col = 0
                        elif nukey == ";5C" or nukey == "C":
                            line = lines[row]
                            charkind(line[col:col+1])
                            kind = charkind(line[col:col+1])
                            kind2 = kind
                            while kind == kind2 and col < len(line):
                                col += 1
                                kind2 = charkind(line[col:col+1])
                            while kind != 2 and kind2 == 2 and col < len(line):
                                col += 1
                                kind2 = charkind(line[col:col+1])
                        elif (nukey == ";5D" or nukey == "D") and col > 0:
                            line = lines[row]
                            charkind(line[col-1:col])
                            kind = charkind(line[col-1:col])
                            kind2 = kind
                            while kind == kind2 and col > 0:
                                col -= 1
                                kind2 = charkind(line[col-1:col])
                            while kind != 2 and kind2 == 2 and col > 0:
                                col -= 1
                                kind2 = charkind(line[col-1:col])
                
                if startrow != row:
                    col = colmem
                    offs = 0
                elif startcol != col:
                    colmem = col
                
                dummyvar = read_input(1)
                
            elif key == '\x0F':  # Ctrl+o
                clear()
                print("Saving file...", end="")
                with open(fname, 'w') as f:
                    for line in lines:
                        f.write(f"{line}{lf}")
                clear()
                print("File saved!")
            else:
                kv = ord(key)
                if 0x20 <= kv < 0x7E or kv == 0x0A:
                    line = lines[row]
                    line = line[:col] + key + line[col:]
                    lines[row] = line
                    col += 1
                    colmem = col
                elif kv == 0:  # Enter
                    line = lines[row]
                    line1 = line[:col]
                    line2 = line[col:]
                    lines[row] = line1
                    row += 1
                    lines.insert(row, line2)
                    col = 0
                    colmem = col
                    offs = 0
                elif kv == 127 or kv == 8:  # Backspace
                    if col > 0:
                        line = lines[row]
                        line = line[:col-1] + line[col:]
                        lines[row] = line
                        col -= 1
                        colmem = col
                    elif row > 0:
                        line1 = lines[row - 1]
                        line2 = lines[row]
                        line = line1 + line2
                        lines[row] = line
                        lines.pop(row - 1)
                        row -= 1
                        col = len(line1)
                        colmem = col

            if row < 0:
                row = 0
            elif row >= len(lines):
                row = len(lines) - 1

            line = lines[row]
            if col >= len(line):
                col = len(line)
            elif col < 0:
                col = 0

            while col - offs >= columns - len(info) - 1:
                offs += 1
            while col < offs:
                offs -= 1

            printify(row, col)

    except KeyboardInterrupt:
        print("")
    finally:
        restore_stdin_echo(old_settings)

if __name__ == "__main__":
    main()