#!/usr/bin/env sh

# WARNING: POTENTIALLY VERY, VERY SLOW
# only use if blined.sh doesn't work!

fname="$1"
flag="$2"

main() {
if [ -z "$fname" ]; then
    echo "Usage: ./poshed.sh <filename> [-s]"; return
fi

if [ ! -e "$fname" ]; then
    echo "No such file \`$fname\`, create it first with \`touch fname\` or \`echo '' > fname\`."; return
fi

lf='
'
linecount=0
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *"$(printf "\r")"*) lf="$(printf "\r\n")" ;;
    esac
    line="$(printf "%s" "$line" | tr -d '\r')"
    eval lines_$linecount="\$line"
    linecount=$((linecount+1))
done < "$fname"

if [ "$flag" != "-s" ]; then
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

text=$(cat "$fname")

secs=$(PATH=`getconf PATH` awk 'BEGIN{srand();print srand()}')

original_settings=$(stty -g)
stty -icanon -echo min 1 time 0

row=0
col=0
colmem=0
offs=0
info=""
columns=72

clear() {
    printf "\33[2K\r"
}

retval=""

getchars() {
    retval=$( timeout --preserve-status --foreground 0.01 cat 2>/dev/null ; printf "\r" )
}
getchars_notimeout() {
    unset retval
    cr=$(printf "\r")
    while [ "$retval" = "" ] || [ "$retval" = "$cr" ] ; do
        getchars
    done
    n=$(expr length "$retval")
    if [ $n -gt 1 ]; then
        retval=$(printf "%s" "$retval" | cut -c "-$(($n-1))") # strip trailing cr
    fi
    if [ "$retval" = "$(printf "\n\r")" ] ; then
        retval=""
    fi
}

did_edit=0
printify() {
    pfrow=$1
    pfcol=$2
    
    nusecs=$(PATH=`getconf PATH` awk 'BEGIN{srand();print srand()}')
    if [ "${DUMBMODE+set}" = "set" ]; then
        :
    elif [ $secs -ne $nusecs ]; then
        secs=$nusecs
        columns=$(stty size 2>/dev/null | cut -d" " -f2)
        if [ "$columns" = "" ]; then
            columns=72
        fi
    fi
    
    info="$(printf '%s' '(line ' $((pfrow+1)) ')')"
    
    eval line="\$lines_$pfrow"
    if [ "${DUMBMODE+set}" = "set" ]; then
        if [ $pfcol -eq 0 ]; then
            line1=""
        else
            line1="$(echo "$line" | cut -c "-$pfcol")"
        fi
        line2="$(echo "$line" | cut -c "$(($pfcol+1))")"
        line3="$(echo "$line" | cut -c "$(($pfcol+2))-")"
        printf "\33[2K\r\033[90m%s\033[0m%s\033[7m%s\033[0m%s" "$info" "$line1" "$line2" "$line3"
    else
        #line=${line:offs:$((columns-${#info}-1))}
        line="$(expr substr "$line" $((offs + 1)) $(($columns - $(expr length "$info") - 1)))"
        n=$(expr length "$info")
        printf "\33[2K\r\033[90m%s\033[0m%s\033[%dG" "$info" "${line}" "$(($n+col+1-offs))"
    fi
}

dodel() {
    eval line="\$lines_$row"
    if [ $col -lt $(expr length "$line") ]; then
        
        if [ $col -eq 0 ]; then
            line="$(printf "%s" "$line" | cut -c "$(($col + 2))-")"
        else
            line="$(printf "%s" "$line" | cut -c "1-$(($col))")$(printf "%s" "$line" | cut -c "$(($col + 2))-")"
        fi
        
        eval lines_$row="\$line"
    elif [ $row -le $linecount ]; then
        rowplus1=$((row+1))
        eval line2="\$lines_$rowplus1"
        line="${line}${line2}"
        
        for i in $(seq $(($row)) $(($linecount-1))); do
            eval lines_$i="\$lines_$(($i+1))"
        done
        
        eval lines_$row="\$line"
        
        linecount=$((linecount-1))
        
        colmem=$col
    fi
}

charkind() { # used for ctrl+left/right word-skipping navigation
    if [ "$1" = "" ]; then
        return 2
    fi
    cv=$(printf "%d" "'$1")
    if [ $cv -ge 48 -a $cv -le 57 ] || [ $cv -ge 65 -a $cv -le 90 ] || [ $cv -ge 97 -a $cv -le 122 ] || [ $cv -gt 127 ]; then
        return 0
    elif [ $cv -ge 33 ]; then
        return 1
    else
        return 2
    fi
}

printify 0 0

getchars

while true; do
    getchars_notimeout
    chars=$retval
    
    key="$(printf "%s" "$chars" | cut -c -1)"
    chars="$(printf "%s" "$chars" | cut -c 2-)"
    
    startcol=$col
    startrow=$row
    if [ "$key" = "$(printf '\e')" ]; then
        pfkey="$(printf "%s" "$chars" | cut -c 1-1)"
        key="$(printf "%s" "$chars" | cut -c 2-2)"
        chars="$(printf "%s" "$chars" | cut -c 3-)"
        fullkey="$pfkey$key"
        unk=0
        if [ "$pfkey" = "O" ] || [ "$pfkey" = "[" ]; then
            if [ "$key" = "3" ]; then
                dodel
            elif [ "$key" = "5" ]; then # pgdn
                row=$((row-50))
            elif [ "$key" = "6" ]; then # pgup
                row=$((row+50))
            elif [ "$key" = "A" ]; then # up
                row=$((row-1))
            elif [ "$key" = "B" ]; then # down
                row=$((row+1))
            elif [ "$key" = "C" ]; then # right
                col=$((col+1))
            elif [ "$key" = "D" ]; then # left
                col=$((col-1))
            elif [ "$key" = "F" -o "$key" = "4" ]; then # end
                eval line="\$lines_$row"
                col=$(expr length "$line")
            else
                unk=1
            fi
        else
            unk=1
        fi
        if [ "$fullkey" = "[H" ] || [ "$fullkey" = "OH" ] || [ "$fullkey" = "O1" ]; then # home
            col=0
            unk=0
        fi
        if [ $unk = 1 ]; then
            if [ "$fullkey" = "[1" -o "$fullkey" = "$(printf '\e[')" -o "$fullkey" = "OC" -o "$fullkey" = "OD" ]; then
                nukey=$chars
                if [ "$nukey" = "~" ]; then # home
                    col=0
                elif [ "$nukey" = ";5C" ] || [ "$nukey" = "C" ]; then # ctrl right / alt right
                    eval line="\$lines_$row"
                    charkind "$(expr substr "$line" $((col+1)) 1)"
                    kind=$?
                    kind2=$kind
                    while [ $kind = $kind2 ] && [ $col -lt ${#line} ]; do # move until different kind is hit
                        col=$((col+1)) ; charkind "${line:col:1}" ; kind2=$?
                    done
                    while [ $kind != 2 ] && [ $kind2 = 2 ] && [ $col -lt ${#line} ]; do # skip repeating spaces if didn't start on space
                        col=$((col+1)) ; charkind "${line:col:1}" ; kind2=$?
                    done
                elif { [ "$nukey" = ";5D" ] || [ "$nukey" = "D" ]; } && [ "$col" -gt 0 ]; then # ctrl left / alt left
                    eval line="\$lines_$row"
                    charkind "$(expr substr "$line" $((col)) 1)"
                    kind=$?
                    kind2=$kind
                    while [ $kind = $kind2 ] && [ $col -gt 0 ]; do # move until different kind is hit
                        col=$((col-1)) ; charkind "${line:$((col-1)):1}" ; kind2=$?
                    done
                    while [ $kind != 2 ] && [ $kind2 = 2 ] && [ $col -gt 0 ]; do # skip repeating spaces if didn't start on space
                        col=$((col-1)) ; charkind "${line:$((col-1)):1}" ; kind2=$?
                    done
                fi
            fi
        fi
        if [ $startrow -ne $row ]; then
            col=$colmem
            offs=0
        elif [ $startcol -ne $col ]; then
            colmem=$col
        fi
    elif [ "$key" = "$(printf '\x0F')" ]; then
        clear
        echo -n "Saving file..."
        
        > "$fname" # clear output file
        
        for i in $(seq 0 $(($linecount-1))); do
            eval line="\$lines_$i"
            printf "%s%s" "$line" "$lf" >> "$fname"
        done
        
        clear
        echo "File saved!"
    elif [ "$key" = "" ] ; then # enter
        eval line="\$lines_$row"
        if [ $col -ne 0 ]; then
            line1="$(printf "%s" "$line" | cut -c 1-"$(($col))")"
            line2="$(printf "%s" "$line" | cut -c "$(($col+1))-")"
        else
            line1=""
            line2="$line"
        fi
        
        eval lines_$row="\$line1"
        row=$((row+1))
        #lines=("${lines[@]:0:$row}" "$line2" "${lines[@]:$row}")
        
        i=$(($linecount-1))
        while [ $i -ge $row ]; do
            eval lines_$(($i+1))="\$lines_$i"
            i=$((i-1))
        done
        eval lines_$row="\$line2"
        linecount=$((linecount+1))
        
        col=0
        colmem=$col
        offs=0
    else
        kv=$(printf "%d" "'$key")
        if [ $kv -ge 32 ] && [ $kv -lt 126 ] || [ $kv -eq 10 ] ; then
            eval line="\$lines_$row"
            #line="${line:0:$col}$key${line:$col}"
            if [ $col -ne 0 ]; then
                line1="$(printf "%s" "$line" | cut -c 1-"$(($col))")"
                line2="$(printf "%s" "$line" | cut -c "$(($col+1))-")"
            else
                line1=""
                line2="$line"
            fi
            line="$line1$key$line2"
            
            eval lines_$row="\$line"
            col=$((col+1))
            colmem=$col
        elif [ $kv -eq 127 ] || [ $kv -eq 8 ]; then # backspace
            if [ $col -gt 0 ]; then
                eval line="\$lines_$row"
                if [ $col -eq 1 ]; then
                    line="$(printf "%s" "$line" | cut -c "$(($col + 1))-")"
                else
                    line="$(printf "%s" "$line" | cut -c "1-$(($col - 1))")$(printf "%s" "$line" | cut -c "$(($col + 1))-")"
                fi
                eval lines_$row="\$line"
                col=$((col-1))
                colmem=$col
            elif [ $row -gt 0 ]; then
                rowminus1=$((row-1))
                eval line1="\$lines_$rowminus1"
                eval line2="\$lines_$row"
                line="${line1}${line2}"
                
                eval lines_$row="\$line"
                
                row=$((row-1))
                for i in $(seq $(($row)) $(($linecount-1))); do
                    eval lines_$i="\$lines_$(($i+1))"
                done
                
                linecount=$((linecount-1))
                
                col=${#line1}
                colmem=$col
            fi
        fi
    fi
    
    if [ $row -lt 0 ]; then
        row=0
    elif [ $row -gt $linecount ]; then
        row=$((linecount - 1))
    fi
    
    eval line="\$lines_$row"
    
    n=$(expr length "$line")
    if [ $col -ge $n ]; then
        col=$n
    elif [ $col -lt 0 ]; then
        col=0
    fi
    
    n=$(expr length "$info")
    while [ $(($col - $offs)) -ge $(($columns-$n-1)) ]; do
        offs=$((offs+1))
    done
    while [ $col -lt $offs ]; do
        offs=$(($offs-1))
    done
    
    printify $row $col
done
} # main

main "$@"

stty "$original_settings"
