decl int radius 15
face global RogueLightBackground 'rgb:202020,black'
decl range-specs in_range
addhl global/roguelight-background fill RogueLightBackground
addhl global/roguelight-in-range ranges in_range
hook global InsertMove .* 'roguelight'

def roguelight %{
    eval -draft -save-regs 'cl/' %{
        exec ';<space>'
        reg c "%val{selection_desc}"
        try %{
            # case where we're at the left border
            exec '<a-k>\A^.\z<ret>'
            reg / "\A(.?.{,%opt{radius}})"
        } catch %{
            # case where we're further than %opt{radius} from the border
            exec hGh
            exec "1s\A(.+).{%opt{radius}}\z<ret>"
            reg / "\A.{%val{selection_length}}(.{,%opt{radius}}.?.{,%opt{radius}})"
        } catch %{
            # case where we're closer than %opt{radius} from the border
            reg / "\A(.{,%val{selection_length}}.?.{,%opt{radius}})"
        }
        exec gh
        eval -save-regs ^ %{
            # put up to 'radius' line up in the mark
            exec -draft -save-regs '' "%opt{radius}<a-C>Z"
            # put up to 'radius' line down in the mark
            exec "%opt{radius}C<a-z>a"
        }
        exec '<a-x>1s<ret>s.<ret>)'

        eval %sh{
            radius="$kak_opt_radius"

            # first, dynamically create a bunch of line_info_X functions, where X goes from 0 to 2*radius+1
            # each function sets the global variables $min_col, $max_col, and $index
            # which respectively represent the minimum column of the line, the maximum column, and the index
            # of the first column in the global $kak_selections array
            # so the yth column can be accessed using $((index + y)) (we use eval later for that)
            # we kind of abuse function declaration to act as a (mostly static) associative array

            center_line=${kak_main_reg_c%%.*}
            center_col=${kak_main_reg_c##*.}

            # first define some dummy line_info_X functions (so that we don't have to deal with empty lines later)
            line=$((2*radius + 1))
            while [ $line -gt 0 ]; do
                line=$((line - 1))
                eval "line_info_$line() { max_col=-1 ; min_col=-1 ; index=-1 ; }"
            done

            # now define the real line_info_X functions using kak_selections_desc
            previous_line=-1
            min_col=-1
            max_col=-1
            start_index=-1
            index=1
            for coord in $kak_selections_desc; do
                line=${coord%%.*}
                col=${coord##*.}

                # line change, we now have full information about the previous line
                if [ $line -ne $previous_line ]; then
                    if [ $previous_line -ne -1 ]; then
                        relative_line_0_based=$((previous_line + radius - center_line))
                        # bake the current values into the new function
                        eval "line_info_$relative_line_0_based() { max_col=$max_col ; min_col=$min_col ; index=$start_index ; }"
                    fi
                    previous_line=$line
                    min_col=$col
                    start_index=$index
                fi
                max_col=$col
                index=$((index+1))
            done
            relative_line_0_based=$((previous_line + radius - center_line))
            eval "line_info_$relative_line_0_based() { max_col=$max_col ; min_col=$min_col ; index=$start_index ; }"

            # sets the 'index' global variable
            # sets it to '#' if outside boundaries
            eval set -- "$kak_selections"
            index_of() {
                real_col=$(($1 + center_col))
                if [ $real_col -lt 0 ]; then
                    index=-1
                    return
                fi
                line_0_based=$(($2 + radius))
                line_info_$line_0_based
                [ $index -eq -1 ] && return
                if [ $real_col -lt $min_col ] || [ $real_col -gt $max_col ]; then
                    index=-1
                    return
                fi
                index=$((index + $1 + radius))
            }

            is_valid() {
                index_of $1 $2
                [ $index -eq -1 ] && return 1
                return 0
            }

            is_opaque() {
                if [ "$1" = ' ' ] || [ "$1" = '
' ]; then return 1; fi
                return 0
            }

            printf 'set window in_range %s' $kak_timestamp
            r2=$((radius * radius))
            octant=8
            while [ $octant -gt 0 ]; do
                octant=$((octant-1))
                if [ $octant -eq 1 ]; then
                    octant_coord() { real_x=$1; real_y=$2; }
                elif [ $octant -eq 2 ]; then
                    octant_coord() { real_x=$2; real_y=$1; }
                elif [ $octant -eq 3 ]; then
                    octant_coord() { real_x=-$2; real_y=$1; }
                elif [ $octant -eq 4 ]; then
                    octant_coord() { real_x=-$1; real_y=$2; }
                elif [ $octant -eq 5 ]; then
                    octant_coord() { real_x=-$1; real_y=-$2; }
                elif [ $octant -eq 6 ]; then
                    octant_coord() { real_x=-$2; real_y=-$1; }
                elif [ $octant -eq 7 ]; then
                    octant_coord() { real_x=$2; real_y=-$1; }
                else
                    octant_coord() { real_x=$1; real_y=-$2; }
                fi
                queue="0|1.0|1.1"
                while [ -n "$queue" ]; do
                    nextqueue=""
                    for cur in $queue; do
                        x=${cur%%|*}
                        [ $x -gt $radius ] && continue
                        cur=${cur#*|}
                        topVec=${cur#*|}
                        topVecX=${topVec%.*}
                        topVecY=${topVec#*.}
                        if [ $x -eq 0 ]; then
                            topY=0
                        else
                            quot=$(((2 * x + 1) * topVecY / (2 * topVecX)))
                            rem=$(((2 * x + 1) * topVecY % (2 * topVecX)))
                            topY=$quot
                            [ $rem -gt $topVecX ] && topY=$((topY + 1))
                        fi

                        bottomVec=${cur%|*}
                        bottomVecX=${bottomVec%.*}
                        bottomVecY=${bottomVec#*.}
                        if [ $x -eq 0 ]; then
                            bottomY=0
                        else
                            quot=$(((2 * x + 1) * bottomVecY / (2 * bottomVecX)))
                            rem=$(((2 * x + 1) * bottomVecY % (2 * bottomVecX)))
                            bottomY=$quot
                            [ $rem -ge $bottomVecX ] && bottomY=$((bottomY + 1))
                        fi

                        y=$topY
                        prevOpaque=-1
                        while [ $y -ge $bottomY ]; do
                            d2=$(( y * y + x * x))
                            if [ $d2 -lt $r2 ]; then
                                octant_coord $x $y
                                if is_valid $real_x $real_y; then
                                    real_x=$((center_col + real_x))
                                    real_y=$((center_line + real_y))
                                    printf ' %s.%s,%s.%s|black,rgb:AAAAAA+F' $real_y $real_x $real_y $real_x
                                fi
                            fi

                            curOpaque=0
                            if [ $d2 -ge $r2 ]; then
                                curOpaque=1
                            else
                                octant_coord $x $y
                                index_of $real_x $real_y
                                eval "char=\"\$$index\""
                                is_opaque "$char" && curOpaque=1
                            fi
                            if [ $prevOpaque -ne -1 ]; then
                                if [ $curOpaque -eq 1 ]; then
                                    if [ $prevOpaque -eq 0 ]; then
                                        nextqueue="$nextqueue $((x+1))|$((x * 2 - 1)).$((y * 2 + 1))|$topVec"
                                    fi
                                elif [ $prevOpaque -eq 1 ]; then
                                    topVec=$((x * 2 + 1)).$((y * 2 +1))
                                fi
                            fi
                            prevOpaque=$curOpaque
                            y=$((y - 1))
                        done
                        if [ $prevOpaque -eq 0 ]; then
                            nextqueue="$nextqueue $((x+1))|$bottomVec|$topVec"
                        fi
                    done
                    queue="$nextqueue"
                done
            done
        }
    }
}
