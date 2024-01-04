#!/bin/bash
# crisis-tools v0.1.0
# (c)José Puga 2023. Under GPL3 License
#
# Brendan Gregg. A script for install crisis tools. Based on:
# "Systems Performance. Entrerprise and the Cloud. 2nd. Edition"


declare -a tools_list

# Feel free to add/remove any tool. 
# NOTE: As Brendan says in his book, package contents may differ between distros. 

# procps
tools_list+=(ps vmstat uptime top)

# util-linux
tools_list+=(dmesg lsblk lscpu)

# sysstat
tools_list+=(iostat mpstat pidstat sar)

# ioroute2
tools_list+=(ip ss nstat tc)

# numactl
tools_list+=(numastat)

# linux-tools
tools_list+=(perf turbostat)

# bcc-tools
# Many more are in /usr/share/bcc/tools. Only one is enought
tools_list+=(opensnoop)

# bpftrace
tools_list+=(bpftrace)

# perf-tools
tools_list+=(ftrace)

# trace-cmd
tools_list+=(trace-cmd)

# nicstat
tools_list+=(nicstat)

# tiptop
tools_list+=(tiptop)

# msr-tools
# TODO: msr-cloud-tools & pmc-cloud-tools from Brendan Gregg Github.



GetOSBased () {
    redhat_based=(rhel centos fedora)
    debian_based=(debian ubuntu)
    os=$(grep ^ID= /etc/os-release | tr -d \" | cut -d = -f2)

    # Check Redhat Based Distributions...
    for n in "${redhat_based[@]}"; do
        if [[ "$n" == "$os" ]]; then
            echo "redhat"
            return 0
        fi
    done

    # Same for Debian...
    for n in "${debian_based[@]}"; do
        if [[ "$n" == "$os" ]]; then
            echo "debian"
            return 0
        fi
    done

    echo $os
    return 1
}

InstallPackages () {
    local os=$1
    shift
    local -a packages=()
    for n in "${to_install[@]}"; do
        case $os in
            "redhat")
                # bcc-tools are in .../tools/ instead .../[s]bin/
                package_name=$(dnf -q provides "*bin/$n" "*/tools/$n" 2>/dev/null \
                     | grep -vE '^$|^Filename|^Repo|^Matched' \
                     | sort -r --version-sort | head -1 | cut -d: -f1)
                ;;
            "debian")
                # OR regex does not work in apt-file
                #package_name=$(apt-file search -x "bin/${n}$|tools/${n}$" 2>/dev/null \
                package_name=$(apt-file search -x "bin/${n}$" 2>/dev/null \
                    | head -1 | cut -d: -f1)               
                [[ "$package_name" == "" ]] && \
                    package_name=$(apt-file search -x "tools/${n}$" 2>/dev/null \
                        | head -1 | cut -d: -f1)
                ;;
            *)
                echo "Unhandler OS '$os'." && exit 1
                ;;
        esac
        # Empty means tool not found
        [[ "$package_name" == "" ]] && echo Tool $n not found. > "$(tty)" && continue
        # Check if package is already selected
        [[ $(echo "${packages[@]}" | grep -w "$package_name") != "" ]] && continue
        packages+=("$package_name")
    done

    case $os in
        "redhat")
            dnf install "${packages[@]}" 
            ;;
        "debian")
            apt install "${packages[@]}" 
            ;;
    esac
}

os=$(GetOSBased)
[[ $? != 0 ]] && echo "Unknow Linux Distribution '$os'." && exit 1
echo Detected OS based: $os

# dpkg -S only works with INSTALLED package. So we need apt-file
[[ "$os" == "debian" ]] && [ "$(which apt-file 2>/dev/null)" == "" ] && echo apt-file must be installed && exit 1
[[ "$os" == "debian" ]] && echo Be sure apt-file DB is updated: 'apt-file update'



#Array with all the utilities not installed yet.
declare -a to_install
for n in "${tools_list[@]}"; do
    filepath="$(whereis $n | awk '{print $2}')"
    # bcc-tools has special location
    [[ $filepath == "" ]] && [[ ! -f "/usr/share/bcc/tools/$n" ]] && to_install+=($n)
    
done

[[ "${#to_install[@]}" == 0 ]] && echo All tools are already installed && exit 0
echo "${#to_install[@]}" tools pending to install: "${to_install[@]}"
echo Searching for packages. This will take a while...
InstallPackages $os
