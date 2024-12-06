#!/usr/bin/env -S awk -f

BEGIN {
    buffer = ""
}

{
    buffer = buffer $0 "\n"
}

END {
    print buffer
}
