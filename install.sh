#!/usr/bin/sh
# shellcheck disable=SC2039
export CLR_RESET="\033[1;0m"
export STL_BOLD="\033[1;1m"
export CLR_RED="\033[0;31m"
export CLR_GREEN="\033[0;32m"
export CLR_BLUE="\033[0;34m"

# Dependencies:
#   vnstat

update()
{
    while true; do
        printf "%b::%b Update system? (%by%b/%bn%b) " "$CLR_BLUE" "$CLR_RESET" "$CLR_GREEN" "$CLR_RESET" "$CLR_GREEN" "$CLR_RESET";
        read -r update
        printf "\033[F\r%b::%b Update system? (y/n) " "$CLR_BLUE" "$CLR_RESET";

        if [ "$update" = "y" ] || [ "$update" = "yes" ]; then
            printf "%byes%b\n" "$CLR_GREEN" "$CLR_RESET";
            printf "\n%b::%b Updating System...\n" "$CLR_BLUE" "$CLR_RESET"

            sudo apt update -y;
            if [ $? != 0 ]; then
                printf "%b!! failed running apt update%b\n" "$CLR_RED" "$CLR_RESET";
                exit 1;
            fi

            sudo apt upgrade -y;
            if [ $? != 0 ]; then
                printf "%b!! Failed running apt upgrade%b\n" "$CLR_RED" "$CLR_RESET";
                exit 1;
            fi

            printf "%b::%b Successfully updated the system\n" "$CLR_GREEN" "$CLR_RESET";
            break;

        elif [ "$update" = "n" ] || [ "$update" = "no" ]; then
            printf "%bno%b\n" "$CLR_GREEN" "$CLR_RESET";
            break;

        elif [ "$update" = "q" ] || [ "$update" = "quit" ]; then
            printf "%bquitting%b\n" "$CLR_RED" "$CLR_RESET";
            exit;
        fi

        printf "%binvalid%b\n\n" "$CLR_RED" "$CLR_RESET";
        printf "%b!!%b Please enter either %by%b or %bn%b\n" "$CLR_RED" "$CLR_RESET" "$CLR_GREEN" "$CLR_RESET" "$CLR_GREEN" "$CLR_RESET";
    done
}

install_required()
{
    printf "\r%b::%b Installing required packages ...\n" "$CLR_BLUE" "$CLR_RESET";
    requirements="$(cat apt_requirements.txt)";
    for requirement in $requirements; do
        printf "\r%b::%b Installing required packages ... %s\n" "$CLR_BLUE" "$CLR_RESET" "$requirement";
        sudo apt install "$requirement" -y;
        if [ $? != 0 ]; then
            printf "\r%b::%b Installing required packages ... %bfail%b\n" "$CLR_BLUE" "$CLR_RESET" "$CLR_RED" "$CLR_RESET";
            exit 1;
        fi
    done

    printf "\r%b::%b Installing required packages ... %bdone%b\n" "$CLR_BLUE" "$CLR_RESET" "$CLR_GREEN" "$CLR_RESET";
}

# shellcheck disable=SC2039
ver() { echo "${1//*[^.0-9]/}"; }


add_systemd()
{
    printf "%b::%b Adding service ..." "$CLR_BLUE" "$CLR_RESET";
    # read the service file and replace placeholders
    service_file="$(cat pi_manager.service)"
    service_file="$(echo "$service_file" | sed "s|<local_path>|$(pwd)/|g")"
    service_file="$(echo "$service_file" | sed "s|<executable>|$1|g")"

    add_failed=0;
    echo "$service_file" | sudo tee /etc/systemd/system/pi_manager.service > /dev/null;
    add_failed=$add_failed || $?;

    sudo systemctl enable pi_manager.service 2> /dev/null;
    add_failed=$add_failed || $?;

    sudo systemctl start pi_manager.service 2> /dev/null;
    add_failed=$add_failed || $?;

    if [ $add_failed != 0 ]; then
        printf "\r%b::%b Adding service ... %bfail%b\n" "$CLR_BLUE" "$CLR_RESET" "$CLR_RED" "$CLR_RESET";
        exit 2;
    fi

    printf "\r%b::%b Adding service ... %bdone%b\n" "$CLR_BLUE" "$CLR_RESET" "$CLR_GREEN" "$CLR_RESET";
}

main() {
    printf "%b::%b Installing PiManager\n" "$CLR_BLUE" "$CLR_RESET";

    # request sudo permissions
    sudo printf "";

    printf "%b::%b Selecting python version ..." "$CLR_BLUE" "$CLR_RESET"
    # define minimum python version required
    min_version_major=3;
    min_version_minor=12;
    min_version_patch=0;

    # List all Python executables in PATH
    python_executables=$(ls -1 /usr/bin/python* 2>/dev/null)

    # Extract the version number from each executable and sort by version number
    sorted_versions=$(for executable in $python_executables
    do
      version=$($executable --version 2>&1 | awk '{print $2}')
      if echo "$version" | grep -Eq "^[0-9]+\.[0-9]+"; then
        echo "$version $executable"
      fi
    done | sort -rV)

    # Get the highest version
    highest_version=$(echo $sorted_versions | awk '{print $1}')

    # Get the executable corresponding to the highest version
    python_executable=$(echo $sorted_versions | awk '{print $2}')

    # Check if highest version is >= 3.10
    major=$(echo "$highest_version" | cut -d. -f1)
    minor=$(echo "$highest_version" | cut -d. -f2)
    patch=$(echo "$highest_version" | cut -d. -f3)

    if [ $major -gt $min_version_major ] || [ $major -eq $min_version_major -a $minor -gt $min_version_minor ] || [ $major -eq $min_version_major -a $minor -eq $min_version_minor -a $patch -ge $min_version_patch ]; then
        printf "\r%b::%b Using python version %b%s%b                   \n" "$CLR_BLUE" "$CLR_RESET" "$CLR_GREEN" "$highest_version" "$CLR_RESET"

    else  # also search /urs/local/bin/ directory if nothing was found
        python_executables=$(ls -1 /usr/local/bin/python* 2>/dev/null)

        # Extract the version number from each executable and sort by version number
        sorted_versions=$(for executable in $python_executables
        do
          version=$($executable --version 2>&1 | awk '{print $2}')
          if echo "$version" | grep -Eq "^[0-9]+\.[0-9]+"; then
            echo "$version $executable"
          fi
        done | sort -rV)

        # Get the highest version
        highest_version=$(echo $sorted_versions | awk '{print $1}')

        # Get the executable corresponding to the highest version
        python_executable=$(echo $sorted_versions | awk '{print $2}')

        # Check if highest version is >= 3.10
        major=$(echo "$highest_version" | cut -d. -f1)
        minor=$(echo "$highest_version" | cut -d. -f2)
        patch=$(echo "$highest_version" | cut -d. -f3)

        if [ $major -gt 3 ] || [ $major -eq 3 -a $minor -gt 9 ] || [ $major -eq 3 -a $minor -eq 10 -a $patch -ge 0 ]; then
            printf "\r%b::%b Using python version %b%s%b                   \n" "$CLR_BLUE" "$CLR_RESET" "$CLR_GREEN" "$highest_version" "$CLR_RESET"

        else
            printf "\r%b::%b Selecting python version %bfail%b                 \n" "$CLR_BLUE" "$CLR_RESET" "$CLR_RED" "$CLR_RESET"
            printf "%b!!%b No python version >=%s found!\n" "$CLR_RED" "$CLR_RESET" "$min_version"
            exit 3
        fi
    fi

    printf "%b::%b Installing pip requirements ...\n" "$CLR_BLUE" "$CLR_RESET"
    "$python_executable" -m pip install -r requirements.txt

    if [ $? != 0 ]; then
        printf "\n%b::%b Installing pip requirements %bfail%b\n" "$CLR_BLUE" "$CLR_RESET" "$CLR_RED" "$CLR_RESET"
        exit 4;
    fi

    printf "\n%b::%b Installing pip requirements %bdone%b\n" "$CLR_BLUE" "$CLR_RESET" "$CLR_GREEN" "$CLR_RESET"

    update;
    install_required;

    add_systemd "$python_executable";

    printf "%b::%b Successfully installed PiManager!\n" "$CLR_BLUE" "$CLR_RESET";
}


main
