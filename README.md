# blined

**blined** is a very small line-based text editor written in pure bash, intended mainly for emergency or system rescue situations, when text editors are inaccessible or broken but the shell is not. blined stands for "bash line editor".

there's also a python version, **plined**, for systems that somehow have a python 3 interpreter but no bash shell.

small: approximately 200 lines of code

fast-ish: tries to use bash builtins whenever possible

modern: insert-based, like notepad. navigation with arrows, home, end, page-up, and page-down all works. backspace and delete both work, even at the starts/ends of lines.

written in 100% pure bash. no ncurses etc needed. tries to use terminal info to support horizontal scrolling, but can be disabled by defining the `DUMBMODE` environment variable to run on even more-broken systems.

![image](https://github.com/user-attachments/assets/f91924e6-4b42-4b87-a4a1-d0c0a0039aff)

## usage

```
# download
curl https://raw.githubusercontent.com/wareya/blined/refs/heads/main/blined.sh > blined.sh
# make executable (on linux/mac os)
chmod +x blined.sh
# use
./blined.sh <filename> [-s]`
```

https://github.com/user-attachments/assets/9018f18b-5277-44fb-ba27-5efb49e8e70f

or, if only python3 is available:

```
# download
curl https://raw.githubusercontent.com/wareya/blined/refs/heads/main/blined.sh > blined.sh
# make executable (on linux/mac os)
chmod +x blined.sh
# use
./blined.sh <filename> [-s]`
```

## installation on systems with no network access or shared filesystem, but with working remote keyboard input

e.g. busted KVMs, VPS interfaces, or virtual machines, where you can "paste" (or emulate a "paste")

```
cat << 'EOFSIGIL' > blined.sh
insert contents of blined.sh here
insert contents of blined.sh here
insert contents of blined.sh here
EOFSIGIL
```

alternatively, if the above doesn't work, but `awk` is available on your system:

```
./bootstrap.awk > blined.sh
<paste the contents of blined.sh>
<hit CTRL+D>
```

then `chmod +x blined.sh` and so on

## license

creative commons zero, public domain
