# Wjebać licencję hunchosową
#!/usr/bin/env bash
#
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
##########################################################################

# Ustaw domyślne ustawienia regionalne, aby niezawodnie obsługiwać dane wyjściowe poleceń
export LANG=pl_PL.UTF-8

# zakończ po każdym błędzie
set -Ee

cd $(dirname $0)
TOP=$(pwd -L)

function wyczysc_pliki_hunchos() {
    echo '
Spowoduje to całkowite usunięcie wszystkich plików zainstalowanych przez hunchos (w tym parowanie
Informacja).
Czy chcesz kontynuować? (t/n)'
    while true; do
        read -N1 -s key
        case $key in
        [Tt])
            sudo rm -rf /var/log/hunchos
            rm -f /var/tmp/hunchos_web_cache.json
            rm -rf "${TMPDIR:-/tmp}/hunchos"
            rm -rf "$HOME/.hunchos"
            sudo rm -rf "/opt/hunchos"
            exit 0
            ;;
        [Nn])
            exit 1
            ;;
        esac
    done
    

}
function pokaz_pomoc() {
    echo '
Użycie: instalacja.sh [opcje]
Przygotuj środowisko do uruchamiania usług Hunchos-AI.

Opcje:
    --clean             Usuwa pliki i foldery utworzone przez ten skrypt
    -h, --help          Pokaż tę wiadomość
    -fm                 Wymuś budowanie naśladowania
    -n, --no-error      Nie kończy pracy w przypadku błędu (używaj ostrożnie)
    -p arg, --python    arg Ustawia używaną wersję języka Python
    -r, --allow-root    Zezwalaj na uruchamianie jako root (np.sudo)
    -sm                 Pomiń kompilację mimiczną
'
}

# Przeanalizuj wiersz poleceń
opt_forcemimicbuild=false
opt_allowroot=false
opt_skipmimicbuild=false
opt_python=python3
param=''

for var in "$@" ; do
    # Sprawdź, czy parametr powinien zostać odczytany
    if [[ $param == 'python' ]] ; then
        opt_python=$var
        param=""
        continue
    fi

    # Sprawdź opcje
    if [[ $var == '-h' || $var == '--help' ]] ; then
        show_help
        exit 0
    fi

    if [[ $var == '--clean' ]] ; then
        if wyczysc_pliki_hunchos; then
            exit 0
        else
            exit 1
        fi
    fi
    

    if [[ $var == '-r' || $var == '--allow-root' ]] ; then
        opt_allowroot=true
    fi

    if [[ $var == '-fm' ]] ; then
        opt_forcemimicbuild=true
    fi
    if [[ $var == '-n' || $var == '--no-error' ]] ; then
        # NIE wychodź w przypadku błędów
	set +Ee
    fi
    if [[ $var == '-sm' ]] ; then
        opt_skipmimicbuild=true
    fi
    if [[ $var == '-p' || $var == '--python' ]] ; then
        param='python'
    fi
done

if [[ $(id -u) -eq 0 && $opt_allowroot != true ]] ; then
    echo 'Ten skrypt nie powinien być uruchamiany jako root ani z sudo.'
    echo 'Jeśli naprawdę tego potrzebujesz, uruchom ponownie z --allow-root'
    exit 1
fi


function found_exe() {
    hash "$1" 2>/dev/null
}


if found_exe sudo ; then
    SUDO=sudo
elif [[ $opt_allowroot != true ]]; then
    echo 'Ten skrypt wymaga "sudo" do zainstalowania pakietów systemowych. Zainstaluj go, a następnie uruchom ponownie ten skrypt.'
    exit 1
fi


function wez_TN() {
    # Pętla, dopóki użytkownik nie naciśnie klawisza Y lub N.
    echo -e -n "Wybierz [${CYAN}T${RESET}/${CYAN}N${RESET}]: "
    while true; do
        read -N1 -s key
        case $key in
        [Tt])
            return 0
            ;;
        [Nn])
            return 1
            ;;
        esac
    done
}

# Jeśli tput jest dostępny i może obsługiwać wiele kolorów
if found_exe tput ; then
    if [[ $(tput colors) != "-1" ]]; then
        GREEN=$(tput setaf 2)
        BLUE=$(tput setaf 4)
        CYAN=$(tput setaf 6)
        YELLOW=$(tput setaf 3)
        RESET=$(tput sgr0)
        HIGHLIGHT=$YELLOW
    fi
fi

# Uruchom kreatora konfiguracji za pierwszym razem, który poprowadzi użytkownika przez niektóre decyzje
if [[ ! -f .dev_opts.json && -z $CI ]] ; then
    echo "
$CYAN                 Witamy w Hunchos-AI $RESET"
    sleep 0.5
    echo '
Ten skrypt ma na celu ułatwienie pracy z Hunchos-AI. Podczas tego
pierwsze uruchomienie instalacji zadamy Ci kilka pytań, które pomogą Ci w konfiguracji
Twoje środowisko.'
    sleep 0.5
    echo "
Chcesz działać na „master” czy przeciwko gałęzi deweloperów? Chyba że jesteś
programista modyfikujący sam Hunchos-AI, powinieneś uruchomić go na
gałąź „główna”. Jest aktualizowany co dwa tygodnie w stabilnej wersji.
  T) ak, uruchom na stabilnej gałęzi „master”
  N) ie, chcę uruchomić niestabilne gałęzie"
    if wez_TN ; then
        echo -e "$HIGHLIGHT Y - za pomocą gałęzi „master” $RESET"
        branch=master
        git checkout ${branch}
    else
        echo -e "$HIGHLIGHT N - przy użyciu niestabilnej gałęzi $RESET"
        branch=dev
    fi

    sleep 0.5
    echo "
Hunchos jest aktywnie rozwijany i stale się rozwija. To jest zalecane
które regularnie aktualizujesz. Czy chcesz aktualizować automatycznie
za każdym razem, gdy uruchamiasz Hunchos? Jest to wysoce zalecane, szczególnie w przypadku
tych, którzy walczą przeciwko gałęzi „głównej”.
  T) es, automatycznie sprawdzaj dostępność aktualizacji
  N) o, będę odpowiedzialny za aktualizowanie Hunchosa."
    if wez_TN ; then
        echo -e "$HIGHLIGHT T - aktualizuj automatycznie $RESET"
        autoupdate=true
    else
        echo -e "$HIGHLIGHT N - aktualizuj ręcznie za pomocą „git pull” $RESET"
        autoupdate=false
    fi

    #  Wyciągnąć mimiczne źródło? Większość będzie zadowolona z samego pakietu
    if [[ $opt_forcemimicbuild == false && $opt_skipmimicbuild == false ]] ; then
        sleep 0.5
        echo '
Hunchos używa technologii Mimic, aby z tobą rozmawiać. Mimic może obsługiwać oba
lokalnie iz serwera. Lokalny Mimic jest bardziej robotyczny, ale zawsze
dostępne niezależnie od łączności sieciowej. Będzie działać jako rozwiązanie awaryjne
jeśli nie można skontaktować się z serwerem Mimic.

Jednak zbudowanie lokalnego Mimika jest czasochłonne - może zająć wiele godzin
na wolniejszych maszynach. Można to pominąć, ale Hunchos nie będzie w stanie tego zrobić
rozmawiaj, jeśli utracisz łączność sieciową. Czy chciałbyś zbudować Mimic
lokalnie?'
        if wez_TN ; then
            echo -e "$HIGHLIGHT T - Mimic zostanie zbudowany $RESET"
        else
            echo -e "$HIGHLIGHT N - pomiń budowę Mimika $RESET"
            opt_skipmimicbuild=true
        fi
    fi

    echo
    # Dodać Hunchos-AI / bin do .bashrc PATH?
    sleep 0.5
    echo '
W folderze bin znajduje się kilka poleceń pomocniczych Hunchos-AI. Te
można dodać do systemu PATH, ułatwiając korzystanie z Hunchos-AI.
Czy chcesz, aby to zostało dodane do Twojej PATH w .profile?'
    if wez_TN ; then
        echo -e "$HIGHLIGHT T - Dodawanie poleceń Hunchosa do ścieżki PATH $RESET"

        if [[ ! -f ~/.profile_Hunchos-AI ]] ; then
            # Dodawaj następujące elementy do .profile tylko wtedy, gdy .profile_Hunchos-AI
            # nie istnieje, co oznacza, że ​​ten skrypt nie był wcześniej uruchamiany
            echo '' >> ~/.profile
            echo '# dołącz polecenia Hunchos-AI' >> ~/.profile
            echo 'źródło ~/.profile_Hunchos-AI' >> ~/.profile
        fi

        echo "
# OSTRZEŻENIE: Ten plik może zostać zastąpiony w przyszłości, nie dostosowuj.
# ustaw ścieżkę tak, aby zawierała narzędzia Hunchosa
if [ -d \"${TOP}/bin\" ] ; then
    PATH=\"\$PATH:${TOP}/bin\"
fi" > ~/.profile_Hunchos-AI
        echo -e "Rodzaj ${CYAN}hunchos-help$RESET aby zobaczyć dostępne polecenia."
    else
        echo -e "$HIGHLIGHT N - PATH pozostało niezmienione $RESET"
    fi

    # Utwórz łącze do folderu „umiejętności”.
    sleep 0.5
    echo
    echo 'Standardowa lokalizacja umiejętności hunchosa to poniżej /opt/hunchos/skills.'
    if [[ ! -d /opt/hunchos/skills ]] ; then
        echo 'Ten skrypt utworzy ten folder dla Ciebie. To wymaga sudo'
        echo 'pozwolenie i może poprosić o hasło...'
        setup_user=$USER
        setup_group=$(id -gn $USER)
        $SUDO mkdir -p /opt/hunchos/skills
        $SUDO chown -R ${setup_user}:${setup_group} /opt/hunchos
        echo 'Utworzony!'
    fi
    if [[ ! -d skills ]] ; then
        ln -s /opt/hunchos/skills skills
        echo "Dla wygody stworzono miękkie łącze o nazwie „umiejętności”, które prowadzi"
        echo 'do /opt/hunchos/skills.'
    fi

    # Add PEP8 pre-commit hook
    sleep 0.5
    echo '
(Programista) Czy chcesz automatycznie sprawdzać styl kodu podczas przesyłania kodu?
Jeśli nie jesteś pewien, odpowiedz tak.
'
    if wez_TN ; then
        echo 'Will install PEP8 pre-commit hook...'
        INSTALL_PRECOMMIT_HOOK=true
    fi

    # Zapisz opcje
    echo '{"use_branch": "'$branch'", "auto_update": '$autoupdate'}' > .dev_opts.json

    echo -e '\nCzęść interaktywna ukończona, teraz instalowane są zależności...\n'
    sleep 5
fi

function os_is() {
    [[ $(grep "^ID=" /etc/os-release | awk -F'=' '/^ID/ {print $2}' | sed 's/\"//g') == $1 ]]
}

function os_is_like() {
    grep "^ID_LIKE=" /etc/os-release | awk -F'=' '/^ID_LIKE/ {print $2}' | sed 's/\"//g' | grep -q "\\b$1\\b"
}

function redhat_common_install() {
    $SUDO yum install -y cmake gcc-c++ git python3-devel libtool libffi-devel openssl-devel autoconf automake bison swig portaudio-devel mpg123 flac curl libicu-devel libjpeg-devel fann-devel pulseaudio
    git clone https://github.com/libfann/fann.git
    cd fann
    git checkout b211dc3db3a6a2540a34fbe8995bf2df63fc9939
    cmake .
    $SUDO make install
    cd "$TOP"
    rm -rf fann

}

function debian_install() {
    APT_PACKAGE_LIST="git python3 python3-dev python3-setuptools libtool \
        libffi-dev libssl-dev autoconf automake bison swig libglib2.0-dev \
        portaudio19-dev mpg123 screen flac curl libicu-dev pkg-config \
        libjpeg-dev libfann-dev build-essential jq pulseaudio \
        pulseaudio-utils"

    if dpkg -V libjack-jackd2-0 > /dev/null 2>&1 && [[ -z ${CI} ]] ; then
        echo "
Wykryliśmy, że na Twoim komputerze jest zainstalowany pakiet libjack-jackd2-0.
Hunchos wymaga pakietu powodującego konflikt i prawdopodobnie odinstaluje ten pakiet.
W niektórych systemach może to spowodować oznaczenie innych programów do usunięcia.
Prosimy o uważne zapoznanie się z poniższymi zmianami w pakiecie."
        read -p "Naciśnij enter aby kontynuować"
        $SUDO apt-get install $APT_PACKAGE_LIST
    else
        $SUDO apt-get install -y $APT_PACKAGE_LIST
    fi
}


function open_suse_install() {
    $SUDO zypper install -y git python3 python3-devel libtool libffi-devel libopenssl-devel autoconf automake bison swig portaudio-devel mpg123 flac curl libicu-devel pkg-config libjpeg-devel libfann-devel python3-curses pulseaudio
    $SUDO zypper install -y -t pattern devel_C_C++
}


function fedora_install() {
    $SUDO dnf install -y git python3 python3-devel python3-pip python3-setuptools python3-virtualenv pygobject3-devel libtool libffi-devel openssl-devel autoconf bison swig glib2-devel portaudio-devel mpg123 mpg123-plugins-pulseaudio screen curl pkgconfig libicu-devel automake libjpeg-turbo-devel fann-devel gcc-c++ redhat-rpm-config jq make
}


function arch_install() {
    $SUDO pacman -S --needed --noconfirm git python python-pip python-setuptools python-virtualenv python-gobject libffi swig portaudio mpg123 screen flac curl icu libjpeg-turbo base-devel jq pulseaudio pulseaudio-alsa

    pacman -Qs '^fann$' &> /dev/null || (
        git clone  https://aur.archlinux.org/fann.git
        cd fann
        makepkg -srciA --noconfirm
        cd ..
        rm -rf fann
    )
}


function centos_install() {
    $SUDO yum install epel-release
    redhat_common_install
}

function redhat_install() {
    $SUDO yum install -y wget
    wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    $SUDO yum install -y epel-release-latest-7.noarch.rpm
    rm epel-release-latest-7.noarch.rpm
    redhat_common_install

}

function gentoo_install() {
    $SUDO emerge --noreplace dev-vcs/git dev-lang/python dev-python/setuptools dev-python/pygobject dev-python/requests sys-devel/libtool virtual/libffi virtual/jpeg dev-libs/openssl sys-devel/autoconf sys-devel/bison dev-lang/swig dev-libs/glib media-libs/portaudio media-sound/mpg123 media-libs/flac net-misc/curl sci-mathematics/fann sys-devel/gcc app-misc/jq media-libs/alsa-lib dev-libs/icu
}

function alpine_install() {
    $SUDO apk add alpine-sdk git python3 py3-pip py3-setuptools py3-virtualenv mpg123 vorbis-tools pulseaudio-utils fann-dev automake autoconf libtool pcre2-dev pulseaudio-dev alsa-lib-dev swig python3-dev portaudio-dev libjpeg-turbo-dev
}

function install_deps() {
    echo 'Instalowanie pakietów...'
    if found_exe zypper ; then
        # OpenSUSE
        echo "$GREEN Instalowanie pakietów dla OpenSUSE...$RESET"
        open_suse_install
    elif found_exe yum && os_is centos ; then
        # CentOS
        echo "$GREEN Instalowanie pakietów dla Centos...$RESET"
        centos_install
    elif found_exe yum && os_is rhel ; then
        # Redhat Enterprise Linux
        echo "$GREEN Instalowanie pakietów dla Red Hat...$RESET"
        redhat_install
    elif os_is_like debian || os_is debian || os_is_like ubuntu || os_is ubuntu || os_is linuxmint; then
        # Debian / Ubuntu / Mint
        echo "$GREEN Instalowanie pakietów dla Debian/Ubuntu/Mint...$RESET"
        debian_install
    elif os_is_like fedora || os_is fedora; then
        # Fedora
        echo "$GREEN Instalowanie pakietów dla Fedora...$RESET"
        fedora_install
    elif found_exe pacman && (os_is arch || os_is_like arch); then
        # Arch Linux
        echo "$GREEN Instalowanie pakietów dla Arch...$RESET"
        arch_install
    elif found_exe emerge && os_is gentoo; then
        # Gentoo Linux
        echo "$GREEN Instalowanie pakietów dla Gentoo Linux ...$RESET"
        gentoo_install
    elif found_exe apk && os_is alpine; then
        # Alpine Linux
        echo "$GREEN Instalowanie pakietów dla Alpine Linux...$RESET"
        alpine_install
    else
    	echo
        echo -e "${YELLOW}Nie można znaleźć menedżera pakietów
${YELLOW}Pamiętaj, aby zainstalować ręcznie:$BLUE git python3 python-setuptools python-venv pygobject libtool libffi libjpg openssl autoconf bison swig glib2.0 portaudio19 mpg123 flac curl fann g++ jq\n$RESET"

        echo 'Ostrzeżenie: nie udało się zainstalować wszystkich zależności. Kontyntynuj? t/n'
        read -n1 continue
        if [[ $continue != 't' ]] ; then
            exit 1
        fi

    fi
}

VIRTUALENV_ROOT=${VIRTUALENV_ROOT:-"${TOP}/.venv"}

function install_venv() {
    $opt_python -m venv "${VIRTUALENV_ROOT}/" --without-pip
    # Wymuś wersję pip dla odtwarzalności, ale nie ma nic specjalnego
    # o tej wersji. Aktualizuj za każdym razem, gdy zostanie wydana nowa wersja i
    # zweryfikowana funkcjonalność.
    curl https://bootstrap.pypa.io/get-pip.py | "${VIRTUALENV_ROOT}/bin/python" - 'pip==20.3.3'
    # Stan funkcji w zależności od tego, czy istnieje pip
    [[ -x ${VIRTUALENV_ROOT}/bin/pip ]]
}

install_deps

# Skonfiguruj do używania standardowego szablonu zatwierdzenia dla
# tylko to repozytorium.
git config commit.template .gitmessage

# Sprawdź, czy zbudować mimikę (zajmuje to naprawdę dużo czasu!)
build_mimic='n'
if [[ $opt_forcemimicbuild == true ]] ; then
    build_mimic='t'
else
    # najpierw poszukaj w folderze kompilacji programu mimic
    has_mimic=''
    if [[ -f ${TOP}/mimic/bin/mimic ]] ; then
        has_mimic=$(${TOP}/mimic/bin/mimic -lv | grep Voice) || true
    fi

    # w nie, sprawdź ścieżkę systemową
    if [[ -z $has_mimic ]] ; then
        if [[ -x $(command -v mimic) ]] ; then
            has_mimic=$(mimic -lv | grep Voice) || true
        fi
    fi

    if [[ -z $has_mimic ]]; then
        if [[ $opt_skipmimicbuild == true ]] ; then
            build_mimic='n'
        else
            build_mimic='t'
        fi
    fi
fi

if [[ ! -x ${VIRTUALENV_ROOT}/bin/activate ]] ; then
    if ! install_venv ; then
        echo 'Nie udało się skonfigurować virtualenv dla hunchosa, wychodzę z instalacji.'
        exit 1
    fi
fi

# Uruchom środowisko wirtualne
source "${VIRTUALENV_ROOT}/bin/activate"
cd "$TOP"

# Install pep8 pre-commit hook
HOOK_FILE='./.git/hooks/pre-commit'
if [[ -n $INSTALL_PRECOMMIT_HOOK ]] || grep -q 'HUNCHOS-AI INSTALACJA' $HOOK_FILE; then
    if [[ ! -f $HOOK_FILE ]] || grep -q 'HUNCHOS-AI INSTALACJA' $HOOK_FILE; then
        echo 'Installing PEP8 check as precommit-hook'
        echo "#! $(which python)" > $HOOK_FILE
        echo '# HUNCHOS-AI INSTALACJA' >> $HOOK_FILE
        cat ./scripts/pre-commit >> $HOOK_FILE
        chmod +x $HOOK_FILE
    fi
fi

PYTHON=$(python -c "import sys;print('python{}.{}'.format(sys.version_info[0], sys.version_info[1]))")

# Dodaj Hunchos-AI do ścieżki virtualenv
# (Jest to równoważne wpisaniu `` add2virtualenv $ TOP '', z wyjątkiem
# nie możesz wywołać tej funkcji powłoki z wnętrza skryptu)
VENV_PATH_FILE="${VIRTUALENV_ROOT}/lib/$PYTHON/site-packages/_virtualenv_path_extensions.pth"
if [[ ! -f $VENV_PATH_FILE ]] ; then
    echo 'import sys; sys.__plen = len(sys.path)' > "$VENV_PATH_FILE" || return 1
    echo "import sys; new=sys.path[sys.__plen:]; del sys.path[sys.__plen:]; p=getattr(sys,'__egginsert',0); sys.path[p:p]=new; sys.__egginsert = p+len(new)" >> "$VENV_PATH_FILE" || return 1
fi

if ! grep -q "$TOP" $VENV_PATH_FILE ; then
    echo 'Dodanie Hunchos-AI do ścieżki virtualenv'
    sed -i.tmp '1 a\
'"$TOP"'
' "$VENV_PATH_FILE"
fi

# zainstaluj wymagane moduły Pythona
if ! pip install -r requirements/requirements.txt ; then
    echo 'Ostrzeżenie: nie udało się zainstalować wszystkich zależności. Kontyntynuj? t/N'
    read -n1 continue
    if [[ $continue != 't' ]] ; then
        exit 1
    fi
fi

# zainstaluj opcjonalne moduły Pythona
if [[ ! $(pip install -r requirements/extra-audiobackend.txt) ||
	! $(pip install -r requirements/extra-stt.txt) ||
	! $(pip install -r requirements/extra-mark1.txt) ]] ; then
    echo 'Ostrzeżenie: nie udało się zainstalować niektórych opcjonalnych zależności. Kontyntynuj? t/N'
    read -n1 continue
    if [[ $continue != 't' ]] ; then
        exit 1
    fi
fi


if ! pip install -r requirements/tests.txt ; then
    echo "Ostrzeżenie: nie udało się zainstalować wymagań testowych. Uwaga: normalna praca powinna nadal działać poprawnie
..."
fi

SYSMEM=$(free | awk '/^Mem:/ { print $2 }')
MAXCORES=$(($SYSMEM / 2202010))
MINCORES=1
CORES=$(nproc)

# ensure MAXCORES is > 0
if [[ $MAXCORES -lt 1 ]] ; then
    MAXCORES=${MINCORES}
fi

# Bądź pozytywnie nastawiony!
if ! [[ $CORES =~ ^[0-9]+$ ]] ; then
    CORES=$MINCORES
elif [[ $MAXCORES -lt $CORES ]] ; then
    CORES=$MAXCORES
fi

echo "Building with $CORES cores."

# zbuduj i zainstaluj pocketsphinx
# zbuduj i zainstaluj mimic

cd "$TOP"

if [[ $build_mimic == 't' || $build_mimic == 'T' ]] ; then
    echo 'OSTRZEŻENIE: Poniższe czynności mogą zająć dużo czasu!'
    "${TOP}/scripts/install-mimic.sh" " $CORES"
else
    echo 'Pomijanie kompilacji mimiki.'
fi

# ustawić uprawnienia dla popularnych skryptów
chmod +x start-hunchos.sh
chmod +x stop-hunchos.sh
chmod +x bin/hunchos-cli-client
chmod +x bin/hunchos-help
chmod +x bin/hunchos-mic-test
chmod +x bin/hunchos-msk
chmod +x bin/hunchos-msm
chmod +x bin/hunchos-pip
chmod +x bin/hunchos-say-to
chmod +x bin/hunchos-skill-testrunner
chmod +x bin/hunchos-speak

# utwórz i ustaw uprawnienia do logowania
if [[ ! -w /var/log/hunchos/ ]] ; then
    # Tworzenie i ustawianie uprawnień
    echo 'Tworzenie /var/log/hunchos/ directory'
    if [[ ! -d /var/log/hunchos/ ]] ; then
        $SUDO mkdir /var/log/hunchos/
    fi
    $SUDO chmod 777 /var/log/hunchos/
fi

# Przechowuj odcisk palca konfiguracji
md5sum requirements/requirements.txt requirements/extra-audiobackend.txt requirements/extra-stt.txt requirements/extra-mark1.txt requirements/tests.txt instalacja.sh > .installed
