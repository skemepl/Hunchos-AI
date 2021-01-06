# Wjebać licencję hunchosową
#!/usr/bin/env bash

# Copyright 2017 Mycroft AI Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SOURCE="${BASH_SOURCE[0]}"

script=${0}
script=${script##*/}
cd -P "$( dirname "$SOURCE" )"

function help() {
    echo "${script}:  Stoper Usług Hunchos"
    echo "usage: ${script} [Usługi]"
    echo
    echo "Usługi:"
    echo "  all       kończy podstawowe usługi: bus, audio, skills, voice"
    echo "  (none)    to samo \"all\""
    echo "  bus       zatrzymaj usługę Hunchos Messagebus"
    echo "  audio     zatrzymaj usługę odtwarzania dźwięku"
    echo "  skills    zatrzymać usługę umiejętności"
    echo "  voice     zatrzymaj usługę przechwytywania głosu"
    echo "  enclosure zatrzymuj usługę enclosure (hardware/gui interface)"
    echo
    echo "Przykłady:"
    echo "  ${script}"
    echo "  ${script} audio"

    exit 0
}

function process-running() {
    if [[ $( pgrep -f "python3 (.*)-m hunchos.*${1}" ) ]] ; then
        return 0
    else
        return 1
    fi
}

function end-process() {
    if process-running $1 ; then
        # Znajdź proces według nazwy, zwracając tylko najstarszy, jeśli ma dzieci
        pid=$( pgrep -o -f "python3 (.*)-m hunchos.*${1}" )
        echo -n "Zatrzymywanie $1 (${pid})..."
        kill -SIGINT ${pid}

        # Zaczekaj do 5 sekund (50 * 0,1) na zatrzymanie procesu
        c=1
        while [ $c -le 50 ] ; do
            if process-running $1 ; then
                sleep 0.1
                (( c++ ))
            else
                c=999   # koniec pętli
            fi
        done

        if process-running $1 ; then
            echo "nie udało się zatrzymać."
            pid=$( pgrep -o -f "python3 (.*)-m hunchos.*${1}" )            
            echo -n "  Zabijanie $1 (${pid})..."
            kill -9 ${pid}
            echo "zabity."
            result=120
        else
            echo "zatrzymany."
            if [ $result -eq 0 ] ; then
                result=100
            fi
        fi
    fi
}


result=0  # domyślnie, nie zmieniać


OPT=$1
shift

case ${OPT} in
    "all")
        ;&
    "")
        echo "Zatrzymywanie wszystkich usług Hunchos-AI"
        end-process skills
        end-process audio
        end-process speech
        end-process enclosure
        end-process messagebus.service
        ;;
    "bus")
        end-process messagebus.service
        ;;
    "audio")
        end-process audio
        ;;
    "skills")
        end-process skills
        ;;
    "voice")
        end-process speech
        ;;
    "enclosure")
        end-process enclosure
        ;;

    *)
        help
        ;;
esac

# Kody zakończenia:
# 0 jeśli nic się nie zmieniło (np. --Help lub żaden proces nie był uruchomiony)
# 100 co najmniej jeden proces został zatrzymany
# 120, jeśli trzeba było zabić jakiś proces
exit $result