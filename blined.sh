#!/usr/bin/env bash

if [ ! -s "$1" ]; then
    echo "Usage: ./blined.sh <filename> [-s]"
    exit
fi

if [ ! -e "$1" ]; then
    echo "No such file `$1`, create it first with \`touch fname\` or \`echo '' > fname\`."
    exit
fi

iscrlf=0
lines=()
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ ${line} == *$'\r'* ]]; then
        iscrlf=1
    fi
    line="${line%$'\r'}"
    lines+=("$line")
done < "$1"

if [[ "$2" != "-s" ]]; then
    printf "Welcome to \033[32mblined\033[0m, the pure bash line-based text editor!\n"
    printf "This is an \033[32minsertion mode\033[0m text editor: you move around with arrow keys and then type stuff.\n"
    printf "blined is primarily meant for \033[30m\033[41memergency usage\033[0m, and lacks most common text editor features.\n"
    printf "Ctrl+o will save the file \033[30m\033[41mimmediately\033[0m, with no prompt or warning.\n"
    printf "Key combinations other than ctrl+o are \033[30m\033[41mnot supported\033[0m. Use ctrl+c to exit.\n"
    echo ""
    printf "You are currently editing:\n"
    echo "$1"
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
    if [ -v DUMBMODE ]; then
        :
    elif [[ $secs -ne $SECONDS ]]; then
        secs=$SECONDS
        columns=$(stty size | cut -d" " -f2)
    fi
    
    clear
    
    pfrow=$1
    pfcol=$2
    info="$(printf '%s' '(line ' $((pfrow+1)) ')')"
    printf "\033[90m%s\033[0m" "$info"
    line=${lines[pfrow]}
    
    if [ -v DUMBMODE ]; then
        echo -en "${line:0:pfcol}"
        printf "\033[7m%s\033[0m" "${line:pfcol:1}"
        echo -en "${line:$((pfcol+1)):$((${#line}-1))}"
    else
        line=${line:offs:$((columns-${#info}-1))}
        printf "%s" "${line}"
        printf "\033[%dG" $((${#info}+col+1-offs))
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

printify 0 0

while true; do
    IFS= read -rsn1 key
    
    if [[ $key == $'\e' ]]; then
        IFS= read -rsn2 -t 0.1 key
        if [[ $key == "[3" ]]; then
            dodel
        elif [[ $key == "[5" ]]; then
            row=$((row-50))
            col=$colmem
            offs=0
        elif [[ $key == "[6" ]]; then
            row=$((row+50))
            col=$colmem
            offs=0
        elif [[ $key == "[A" || $key == "OA" ]]; then
            row=$((row-1))
            col=$colmem
            offs=0
        elif [[ $key == "[B" || $key == "OB" ]]; then
            row=$((row+1))
            col=$colmem
            offs=0
        elif [[ $key == "[C" || $key == "OC" ]]; then
            col=$((col+1))
            colmem=$col
        elif [[ $key == "[D" || $key == "OD" ]]; then
            col=$((col-1))
            colmem=$col
        elif [[ $key == "OH" || $key == "[1" ]]; then
            col=0
            colmem=$col
        elif [[ $key == "OF" || $key == "[4" ]]; then
            line=${lines[row]}
            col=${#line}
            colmem=$col
        else
            #echo "Unknown key sequence: $key"
            :
        fi
    elif [[ $key == $'\x0F' ]]; then
        clear
        echo -n "Saving file..."
        
        > "$1"
        if (( iscrlf == 1 )); then
            for line in "${lines[@]}"; do
                printf "%s\r\n" "$line" >> "$1"
            done
        else
            for line in "${lines[@]}"; do
                echo "$line" >> "$1"
            done
        fi
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
    fi
    if [[ $row -ge ${#lines[@]} ]]; then
        row=$((${#lines[@]}))
    fi
    
    line=${lines[row]}
    
    if [[ $col -ge ${#line} ]]; then
        col=$((${#line}))
    fi
    if [[ $col -lt 0 ]]; then
        col=0
    fi
    
    while [[ $(($col - offs)) -ge $((columns-${#info}-1)) ]]
    do
        offs=$((offs+1))
    done
    while [[ $col -lt $offs ]]
    do
        offs=$((offs-1))
    done
    
    printify row col
done
