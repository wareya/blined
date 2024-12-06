#!/usr/bin/env bash

fname="$1"
flag="$2"

main() {
if [ -z "$fname" ]; then
    echo "Usage: ./blined.sh <filename> [-s]"; return
fi

if [ ! -e "$fname" ]; then
    echo "No such file \`$fname\`, create it first with \`touch fname\` or \`echo '' > fname\`."; return
fi

lf=$'\n'
#lines=()
set -A lines
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ ${line} == *$'\r'* ]]; then
        lf=$'\r\n'
    fi
    line="${line%$'\r'}"
    #lines+=("$line")
    lines[${#lines[*]}]="${line%$'\r'}"
done < "$fname"

if [[ "$flag" != "-s" ]]; then
    printf "Welcome to \033[32mblined\033[0m, the pure bash line-based text editor!\n"
    printf "This is an \033[32minsertion mode\033[0m text editor: you move around with arrow keys and start typing.\n"
    printf "Home, end, pgup, pgdn, backspace, and del should work. If not, please open a bug report.\n"
    printf "blined is mainly meant for \033[30m\033[41memergency usage\033[0m, and lacks most common text editor features.\n"
    printf "Ctrl+o will save the file \033[30m\033[41mimmediately\033[0m, with no prompt or warning.\n"
    printf "Key combinations other than ctrl+o are \033[30m\033[41mnot supported\033[0m. Use ctrl+c to exit.\n"
    echo ""
    printf "You are currently editing:\n"
    echo "$fname"
    echo ""
fi

secs=$SECONDS

row=0
col=0
colmem=0
offs=0
info=""
columns=72

clear() {
    printf "\33[2K\r"
}

printify() {
    pfrow=$1
    pfcol=$2
    
    if [ -v DUMBMODE ]; then
        :
    elif [[ $secs -ne $SECONDS ]]; then
        secs=$SECONDS
        columns=$(stty size | cut -d" " -f2)
    fi
    
    info="$(printf '%s' '(line ' $((pfrow+1)) ')')"
    line=${lines[pfrow]}
    
    if [ -v DUMBMODE ]; then
        printf "\33[2K\r\033[90m%s\033[0m%s\033[7m%s\033[0m%s" "$info" "${line:0:pfcol}" "${line:pfcol:1}" "${line:$((pfcol+1)):$((${#line}-1))}"
    else
        line=${line:offs:$((columns-${#info}-1))}
        printf "\33[2K\r\033[90m%s\033[0m%s\033[%dG" "$info" "${line}" "$((${#info}+col+1-offs))"
    fi
}

dodel() {
    line=${lines[row]}
    if (( col < ${#line} )); then
        line=${lines[row]}
        line="${line:0:$col}${line:$(($col+1))}"
        lines[row]=$line
    elif (( row + 1 < ${#lines[@]} )); then
        line1=${lines[row]}
        line2=${lines[row+1]}
        line="${line1}${line2}"
        
        lines=("${lines[@]:0:$row}" "${lines[@]:$(($row+1))}")
        lines[row]=$line
        
        col=${#line1}
        colmem=$col
    fi
}

charkind() { # used for ctrl+left/right word-skipping navigation
    if [[ "$1" == "" ]]; then
        return 2
    fi
    cv=$(printf "%d" "'$1")
    if (( cv >= 0x30 && cv <= 0x39 )) || (( cv >= 0x41 && cv <= 0x5A )) || (( cv >= 0x61 && cv <= 0x7A )) || (( cv > 0x7F )); then
        return 0
    elif (( cv >= 0x21 )); then
        return 1
    else
        return 2
    fi
}

stty -echo

printify 0 0

while true; do
    IFS= read -rsn1 key
    
    startcol=$col
    startrow=$row
    if [[ $key == $'\e' ]]; then
        IFS= read -rsn1 -t 0.01 pfkey
        IFS= read -rsn1 -t 0.01 key
        fullkey="$pfkey$key"
        unk=0
        if [[ $pfkey == "O" || $pfkey == "[" ]]; then
            if [[ $key == "3" ]]; then
                dodel
            elif [[ $key == "5" ]]; then # pgdn
                row=$((row-50))
            elif [[ $key == "6" ]]; then # pgup
                row=$((row+50))
            elif [[ $key == "A" ]]; then # up
                row=$((row-1))
            elif [[ $key == "B" ]]; then # down
                row=$((row+1))
            elif [[ $key == "C" ]]; then # right
                col=$((col+1))
            elif [[ $key == "D" ]]; then # left
                col=$((col-1))
            elif [[ $key == "F" || $key == "4" ]]; then # end
                line=${lines[row]}
                col=${#line}
            else
                unk=1
            fi
        else
            unk=1
        fi
        if [[ $fullkey == "[H" || $fullkey == "OH" || $fullkey == "O1" ]]; then # home
            col=0
            unk=0
        fi
        if [[ $unk == 1 ]]; then
            if [[ $fullkey == "[1" || $fullkey == $'\e[' || $fullkey == "OC" || $fullkey == "OD" ]]; then
                IFS= read -rsn3 -t 0.01 nukey
                if [[ $nukey == "~" ]]; then # home
                    col=0
                elif [[ ( $nukey == ";5C" ) || ( $nukey == "C" ) ]]; then # ctrl right / alt right
                    line=${lines[row]}
                    charkind "${line:col:1}"
                    kind=$?
                    kind2=$kind
                    while [[ ( $kind == $kind2 ) && ( $col -lt ${#line} ) ]]; do # move until different kind is hit
                        col=$((col+1)) ; charkind "${line:col:1}" ; kind2=$?
                    done
                    while [[ ( $kind != 2 ) && ( $kind2 == 2 ) && ( $col -lt ${#line} ) ]]; do # skip repeating spaces if didn't start on space
                        col=$((col+1)) ; charkind "${line:col:1}" ; kind2=$?
                    done
                elif [[ ( ( $nukey == ";5D" ) || ( $nukey == "D" ) ) && ( $col -gt 0 ) ]]; then # ctrl left / alt left
                    line=${lines[row]}
                    charkind "${line:$((col-1)):1}"
                    kind=$?
                    kind2=$kind
                    while [[ ( $kind == $kind2 ) && ( $col -gt 0 ) ]]; do # move until different kind is hit
                        col=$((col-1)) ; charkind "${line:$((col-1)):1}" ; kind2=$?
                    done
                    while [[ ( $kind != 2 ) && ( $kind2 == 2 ) && ( $col -gt 0 ) ]]; do # skip repeating spaces if didn't start on space
                        col=$((col-1)) ; charkind "${line:$((col-1)):1}" ; kind2=$?
                    done
                fi
            fi
        fi
        if [[ $startrow -ne $row ]]; then
            col=$colmem
            offs=0
        elif [[ $startcol -ne $col ]]; then
            colmem=$col
        fi
        IFS= read -rsn9 -t 0.01 dummyvar # chomp any stray escape characters before they get to text input
    elif [[ $key == $'\x0F' ]]; then
        clear
        echo -n "Saving file..."
        
        > "$fname" # clear output file
        for line in "${lines[@]}"; do # write each line to it
            printf "%s$s" "$line" "$lf" >> "$fname"
        done
        clear
        echo "File saved!"
    else
        kv=$(printf "%d" "'$key")
        if (( kv >= 0x20 && kv < 0x7E )) || (( kv == 0x0A )); then
            line=${lines[row]}
            line="${line:0:$col}$key${line:$col}"
            lines[row]=$line
            col=$((col+1))
            colmem=$col
        elif (( kv == 0 )); then # enter
            line=${lines[row]}
            line1=${line:0:$col}
            line2=${line:$col}
            
            lines[row]=$line1
            row=$((row+1))
            lines=("${lines[@]:0:$row}" "$line2" "${lines[@]:$row}")
            
            col=0
            colmem=$col
            offs=0
        elif (( kv == 127 || kv == 8 )); then # backspace
            if (( col > 0 )); then
                line=${lines[row]}
                line="${line:0:$(($col-1))}${line:$col}"
                lines[row]=$line
                col=$((col-1))
                colmem=$col
            elif (( row > 0 )); then
                line1=${lines[row-1]}
                line2=${lines[row]}
                line="${line1}${line2}"
                
                lines[row]=$line
                lines=("${lines[@]:0:$(($row-1))}" "${lines[@]:$row}")
                row=$((row-1))
                
                col=${#line1}
                colmem=$col
            fi
        fi
    fi
    
    if [[ $row -lt 0 ]]; then
        row=0
    elif [[ $row -ge ${#lines[@]} ]]; then
        row=$((${#lines[@]}))
    fi
    
    line=${lines[row]}
    
    if [[ $col -ge ${#line} ]]; then
        col=$((${#line}))
    elif [[ $col -lt 0 ]]; then
        col=0
    fi
    
    while [[ $(($col - offs)) -ge $((columns-${#info}-1)) ]]; do
        offs=$((offs+1))
    done
    while [[ $col -lt $offs ]]; do
        offs=$((offs-1))
    done
    
    printify row col
done
} # main

main "$@"
