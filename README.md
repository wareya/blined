# blined

blined is a very small line-based text editor written in pure bash, intended mainly for emergency or system rescue situations, when text editors are inaccessible or broken but the shell is not. blined stands for "bash line editor".

small: approximately 200 lines of code

fast-ish: tries to use bash builtins whenever possible

modern: insert-based, like notepad. navigation with arrows, home, end, page-up, and page-down all works. backspace and delete both work, even at the starts/ends of lines.

![image](https://github.com/user-attachments/assets/101d9a35-136f-449b-9775-f44166cb79a9)

## usage

```
# download
curl https://raw.githubusercontent.com/wareya/blined/refs/heads/main/blined.sh > blined.sh
# make executable (on linux/mac os)
chmod +x blined.sh
# use
./blined.sh <filename> [-s]`
```

https://github.com/user-attachments/assets/bbd1c69c-8a44-463b-8141-4f08b275740f

## license

creative commons zero, public domain
