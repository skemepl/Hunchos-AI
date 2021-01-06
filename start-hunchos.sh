
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
DIR="$( pwd )"
VIRTUALENV_ROOT=${VIRTUALENV_ROOT:-"${DIR}/.venv"}

function help() {
    echo "${script}:  Hunchos polecenie/program uruchamiający "
    echo "usage: ${script} [Polecenie] [restart] [params]"
    echo
    echo "Dostępne polecenia:"
    echo "  all                      prowadzi podstawowe usługi: bus, audio, skills, voice"
    echo "  debug                    prowadzi usługi podstawowe, then starts the CLI"
    echo "  audio                    usługa odtwarzania dźwięku"
    echo "  bus                      usługa Messagebus"
    echo "  skills                   usługa umiejętności"
    echo "  voice                    usługa przechwytywania głosu"
    # echo "  wifi                     usługa konfiguracji wifi"
    # echo "  enclosure                mark_1 enclosure service"
    echo
    echo "Narzędzia poleceń:"
    echo "  cli                      interfejs wiersza poleceń"
    echo "  unittest                 uruchom testy jednostkowe Hunchos-AI (wymaga pytest)"
    echo "  skillstest               uruchom autotesty umiejętności dla wszystkich umiejętności (wymaga pytest)"
    echo "  vktest                   uruchom pakiet testów integracji Voight Kampff"
    echo
    echo "Przydatne polecenia:"
    echo "  audiotest                spróbuj prostej weryfikacji dźwięku"
    echo "  wakewordtest             przetestuj wybrany silnik wakeword"
    echo "  sdkdoc                   wygeneruj dokumentację sdk"
    echo
    echo "Opcje:"
    echo "  restart                  (opcjonalnie) Wymuś ponowne uruchomienie usługi, jeśli jest uruchomiona"
    echo
    echo "Przykłady:"
    echo "  ${script} all"
    echo "  ${script} all restart"
    echo "  ${script} cli"
    echo "  ${script} unittest"

    exit 1
}

_module=""
function name-to-script-path() {
    case ${1} in
        "bus")               _module="hunchos.messagebus.service" ;;
        "skills")            _module="hunchos.skills" ;;
        "audio")             _module="hunchos.audio" ;;
        "voice")             _module="hunchos.client.speech" ;;
        "cli")               _module="hunchos.client.text" ;;
        "audiotest")         _module="hunchos.util.audio_test" ;;
        "wakewordtest")      _module="test.wake_word" ;;
        "enclosure")         _module="hunchos.client.enclosure" ;;

        *)
            echo "Error: Nieprawidłowa nazwa '${1}'"
            exit 1
    esac
}

function source-venv() {
    # Wejdź do wirtualnego środowiska Python, chyba że pod Dockerem
    if [ ! -f "/.dockerenv" ] ; then
        source ${VIRTUALENV_ROOT}/bin/activate
    fi
}

first_time=true
function init-once() {
    if ($first_time) ; then
        echo "Inicjowanie..."
        "${DIR}/scripts/prepare-msm.sh"
        source-venv
        first_time=false
    fi
}

function launch-process() {
    init-once

    name-to-script-path ${1}

    # Uruchom proces na pierwszym planie
    echo "Startowanie $1"
    python3 -m ${_module} $_params
}

function require-process() {
    # Uruchom proces, jeśli nie zostanie znaleziony
    name-to-script-path ${1}
    if ! pgrep -f "python3 (.*)-m ${_module}" > /dev/null ; then
        # Rozpocznij wymagany proces
        launch-background ${1}
    fi
}

function launch-background() {
    init-once

    # Sprawdź, czy dany moduł działa i uruchom (lub uruchom ponownie, jeśli działa)
    name-to-script-path ${1}
    if pgrep -f "python3 (.*)-m ${_module}" > /dev/null ; then
        if ($_force_restart) ; then
            echo "Restartowanie: ${1}"
            "${DIR}/stop-hunchos.sh" ${1}
        else
            # Już działa, nie ma potrzeby ponownego uruchamiania
            return
        fi
    else
        echo "Uruchamiam usługę w tle $1"
    fi

    # Ostrzeżenie / przypomnienie dotyczące bezpieczeństwa dla użytkownika
    if [[ "${1}" == "bus" ]] ; then
        echo "UWAGA: Magistrala Hunchos to otwarte gniazdo sieciowe bez wbudowanych zabezpieczeń"
        echo "         środki. Jesteś odpowiedzialny za ochronę portu lokalnego"
        echo "         8181 z odpowiednią zaporą."
    fi

    # Uruchom proces w tle, wysyłając logi do standardowej lokalizacji
    python3 -m ${_module} $_params >> /var/log/hunchos/${1}.log 2>&1 &
}

function launch-all() {
    echo "Uruchomienie wszystkich usług Hunchos-AI"
    launch-background bus
    launch-background skills
    launch-background audio
    launch-background voice
    launch-background enclosure
}

function check-dependencies() {
    if [ -f .dev_opts.json ] ; then
        auto_update=$( jq -r ".auto_update" < .dev_opts.json 2> /dev/null)
    else
        auto_update="false"
    fi
    if [ "$auto_update" == "true" ] ; then
        # Sprawdź repozytorium github pod kątem aktualizacji (np. Nowej wersji)
        git pull
    fi

    if [ ! -f .installed ] || ! md5sum -c &> /dev/null < .installed ; then
        # Pliki krytycznie uległy zmianie, instalacja.sh należy uruchomić ponownie
        if [ "$auto_update" == "true" ] ; then
            echo "Aktualizowanie zależności..."
            bash instalacja.sh
        else
            echo "Zaktualizuj zależności, uruchamiając ponownie ./instalacja.sh."
            if command -v notify-send >/dev/null ; then
                # Wygeneruj powiadomienie na pulpicie (ArchLinux)
                notify-send "Zależności Hunchos nieaktualne "" Uruchom ponownie ./instalacja.sh"
            fi
            exit 1
        fi
    fi
}

_opt=$1
_force_restart=false
shift
if [[ "${1}" == "restart" ]] || [[ "${_opt}" == "restart" ]] ; then
    _force_restart=true
    if [[ "${_opt}" == "restart" ]] ; then
        # Wsparcie „start-hunchos.sh restart all” oraz „start-hunchos.sh all restart”
        _opt=$1
    fi
    shift
fi
_params=$@

check-dependencies

case ${_opt} in
    "all")
        launch-all
        ;;

    "bus")
        launch-background ${_opt}
        ;;
    "audio")
        launch-background ${_opt}
        ;;
    "skills")
        launch-background ${_opt}
        ;;
    "voice")
        launch-background ${_opt}
        ;;

    "debug")
        launch-all
        launch-process cli
        ;;

    "cli")
        require-process bus
        require-process skills
        launch-process ${_opt}
        ;;

    # TODO: Przywróć obsługę konfiguracji Wi-Fi na Picrofcie itp.
    # „wifi”)
    # launch-background $ {_ opt}
    # ;;
    "unittest")
        source-venv
        pytest test/unittests/ --cov=hunchos "$@"
        ;;
    "singleunittest")
        source-venv
        pytest "$@"
        ;;
    "skillstest")
        source-venv
        pytest test/integrationtests/skills/discover_tests.py "$@"
        ;;
    "vktest")
        source "$DIR/bin/hunchos-skill-testrunner" vktest "$@"
        ;;
    "audiotest")
        launch-process ${_opt}
        ;;
    "wakewordtest")
        launch-process ${_opt}
        ;;
    "sdkdoc")
        source-venv
        cd doc
        make ${_params}
        cd ..
        ;;
    "enclosure")
        launch-background ${_opt}
        ;;

    *)
        help
        ;;
esac
