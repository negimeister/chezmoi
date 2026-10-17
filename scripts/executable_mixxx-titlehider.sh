
#!/bin/bash

obs-websocket.py &
show_title(){
    curl -XPOST  -H "Content-type: application/json" -d "{\"item\":\"title_hider_$1\", \"visible\":false}" 'http://127.0.0.1:4445/call/SetSceneItemProperties'
}

hide_title(){
    curl -XPOST  -H "Content-type: application/json" -d "{\"item\":\"title_hider_$1\", \"visible\":true}" 'http://127.0.0.1:4445/call/SetSceneItemProperties'
}

aseqdump -p "MixTrack Platinum" | \
    while read l; do
        if [[ $l == *"2, note 16, velocity 127"* ]]; then
            hide_title 3
        elif  [[ $l == *"3, note 16, velocity 127"* ]]; then
            hide_title 4
        elif [[ $l == *"2, note 0, velocity 127"* ]]; then
            show_title 3
        elif [[ $l == *"3, note 0, velocity 127"* ]]; then
            show_title 4
        fi
    done &

aseqdump -p DJ2GO | \
    while read l; do
        if [[ $l == *"15, note 2, velocity 127"* ]]; then
            hide_title 1
        elif  [[ $l == *"15, note 3, velocity 127"* ]]; then
            hide_title 2
        elif [[ $l == *"0, note 0, velocity 127"* ]]; then
            show_title 1
        elif [[ $l == *"1, note 0, velocity 127"* ]]; then
            show_title 2
        fi
    done

kill $(jobs -p)
