#!/bin/bash
#set -x

SUCCESS=0
ERROR=1

exit_code=${ERROR}
return_code=${SUCCESS}
msg="FAIL"

# We must be root
my_uid=$(id -un 2> /dev/null)

if [ "${my_uid}" = "root" ]; then

    # We must have SSH_PUBKEY and SSH_PRIVKEY environment variables defined
    if [ "${SSH_PUBKEY}" != "" -a "${SSH_PRIVKEY}" != "" ]; then

        # Populate /root/.ssh folder with keys
        ssh_key_dir="/root/.ssh"
        pubkey_file="${ssh_key_dir}/id_rsa.pub"
        privkey_file="${ssh_key_dir}/id_rsa"

        if [ ! -d "${ssk_key_dir}" ]; then
            mkdir -p "${ssh_key_dir}"
            chmod 700 "${ssh_key_dir}"
        fi

        for i in ${SSH_PUBKEY} ; do
            echo "${i}" | sed -e 's?::zzQc::?\ ?g'
        done > "${pubkey_file}"

        chmod 660 "${pubkey_file}"

        for i in ${SSH_PRIVKEY} ; do
            echo "${i}" | sed -e 's?::zzQc::?\ ?g'
        done > "${privkey_file}"

        chmod 600 "${privkey_file}"

        ln -s "${pubkey_file}"  "${ssh_key_dir}/authorized_keys"
        ln -s "${privkey_file}" "${ssh_key_dir}/identity"

        # Populate /root/.ssh/config with useful defaults
        cat > "${ssh_key_dir}/config" << EOF_CONFIG
Host bitbucket
  Hostname bitbucket.ingramcontent.com
  User svcbambdev
  IdentityFile ~/.ssh/identity
  StrictHostKeyChecking no

Host stash
  Hostname stash.ingramcontent.com
  User svcbambdev
  IdentityFile ~/.ssh/identity
  StrictHostKeyChecking no

Host *
  ForwardX11 yes
  ForwardX11Trusted yes
  Loglevel ERROR
EOF_CONFIG

        # Make sure we have git installed
        my_git=$(which git 2> /dev/null)

        if [ "${my_git}" != "" ]; then
        
            if [ "${1}" = "master" ]; then
                scm_branch="${1}"
            else
                scm_branch="dev"
            fi
        
            # Setup initial /etc/resolv.conf to talk to TLD DNS server
            ndjbdns_dir="/etc/ndjbdns"

            if [ -d "${ndjbdns_dir}" ]; then
                icg_dns[0]="172.18.60.53"
                icg_dns[1]="172.18.68.21"

                icg_domain[0]="ingramcontent.com"
                icg_domain[1]="ingrambook.com"
                icg_domain[2]="lightningsource.com"

                search_line=""

                target_file="/etc/resolv.conf"

                for icg_dom in ${icg_domain[*]} ; do

                    if [ "${search_line}" = "" ]; then
                        search_line="${icg_dom}"
                    else
                        search_line="${search_line} ${icg_dom}"
                    fi

                done

                echo "search ${search_line}" > "${target_file}"

                for icg_ns in ${icg_dns[*]} ; do
                    echo "nameserver ${icg_ns}" >> "${target_file}"
                done

                # Now add ICG searching capability to DJBDNS (needed later)
                for icg_dom in ${icg_domain[*]} ; do
                    target_file="${ndjbdns_dir}/servers/${icg_dom}"

                    if [ -e "${target_file}" ]; then
                        rm "${target_file}"
                    fi

                    for icg_ns in ${icg_dns[*]} ; do
                        echo "${icg_ns}" >> "${target_file}"
                    done

                done

                # Setup for SCM repo checkout
                working_dir="/var/git/repo"
                #scm_user="svcbambdev"
                scm_host="stash"
                scm_port="7999"
                scm_path="dns"
                scm_repo="lab.ingram.io"
        
                if [ "${scm_user}" != "" ]; then
                    scm_url="ssh://${scm_user}@${scm_host}:${scm_prt}/${scm_path}/${scm_repo}.git"
                else
                    scm_url="ssh://${scm_host}:${scm_port}/${scm_path}/${scm_repo}.git"
                fi
        
                # Make sure our repo directory exists
                if [ ! -d "${working_dir}" ]; then
                    mkdir -p "${working_dir}" 2> /dev/null
                fi
        
                # Change to repo directory and checkout stuff
                echo "Cloning DNS project"
                cd "${working_dir}" 2> /dev/null && ${my_git} clone ${scm_url} #> /dev/null 2>&1
        
                if [ -d "${working_dir}/${scm_repo}" ]; then
                    cd "${working_dir}/${scm_repo}" 
                    echo "Checking ${scm_branch} branch of DNS project"
                    ${my_git} checkout ${scm_branch} #> /dev/null 2>&1
                    let return_code=${return_code}+${?}
        
                    if [ ${return_code} -eq ${SUCCESS} ]; then
                        echo "Contructing TinyDNS datafile"
                        make tinydns #> /dev/null 2>&1

                        case ${scm_branch} in

                            master)

                                # Setup this domain's data file
                                cp tinydns.data "${ndjbdns_dir}" &&
                                cd "${ndjbdns_dir}" && tinydns-data data
                            ;;

                        esac

                        # Gather SOA records from tinydns.data
                        my_soa_records=$(egrep "^\." tinydns.data | awk -F':' '{print $1 ":" $2}' | sed -e 's/^.//g')

                        # Switch to ${ndjbdns_dir} and setup this domain's SOA data files
                        cd "${ndjbdns_dir}" &&

                        for soa_record in ${my_soa_records} ; do
                            file_name=$(echo "${soa_record}" | awk -F':' '{print $1}')
                            file_data=$(echo "${soa_record}" | awk -F':' '{print $NF}')

                            target_file="${ndjbdns_dir}/servers/${file_name}"

                            if [ -e "${ndjbdns_dir}/servers/${file_name}" ]; then
                                rm "${ndjbdns_dir}/servers/${file_name}"
                            fi

                            echo "${file_data}" > "${ndjbdns_dir}/servers/${file_name}"

                            let forward_check=$(echo "${file_name}" | egrep -i "^[a-z]" | wc -l | awk '{print $1}')
                            let reverse_check=$(echo "${file_name}" | egrep "^[0-9]" | wc -l | awk '{print $1}')

                            if [ ${forward_check} -gt 0 ]; then
                                lab_dns_domain="${file_name}"
                            fi

                            if [ ${reverse_check} -gt 0 ]; then
                                lab_arpa_range="${file_name}"
                            fi
                  
                        done &&
        
                        if [ "${lab_dns_domain}" = "" -o "${lab_arpa_range}" = "" ]; then
                            /bin/false
                        else

                            # Permit the ip address specified by any in-arpa SOA records to talk to TinyDNS
                            octet_list=$(echo "${file_name}" | sed -e 's/\.in-addr\.arpa//g' -e 's/\./\ /g')
                            octets=( ${octet_list} );
                            let octet_count=${#octets[*]}-1

                            lab_ip_range=""

                            while [ ${octet_count} -ge 0 ]; do

                                if [ "${lab_ip_range}" = "" ]; then
                                    lab_ip_range="${octets[$octet_count]}"
                                else
                                    lab_ip_range="${lab_ip_range}.${octets[$octet_count]}"
                                fi

                                let octet_count=${octet_count}-1
                            done

                            touch "${ndjbdns_dir}/ip/${lab_ip_range}"
                        fi

                        let return_code=${return_code}+${?}

                        if [ ${return_code} -eq ${SUCCESS} ]; then
                            my_ipaddress=""
        
                            # Configure TinyDNS services for this container
                            my_eth_device=$(netstat -i 2> /dev/null | egrep -iv "^iface|^kernel|^lo" | awk '{print $1}' | head -1)

                            if [ "${my_eth_device}" != "" ]; then
                                my_ipaddress=$(ifconfig ${my_eth_device} 2> /dev/null | egrep "inet addr:" | awk '{print $2}' | awk -F':' '{print $NF}')
        
                                if [ "${my_ipaddress}" != "" ]; then
        
                                    # Put ${my_ipaddress} in /etc/resolv.conf for local DNS services
                                    target_file="/etc/resolv.conf"
                                    echo "Seeding ${target_file} with useful values"
                                    echo "domain ${lab_dns_domain}"    > "${target_file}"
                                    echo "search ${lab_dns_domain}"   >> "${target_file}"
                                    echo "nameserver ${my_ipaddress}" >> "${target_file}"
        
                                    # Put ${my_ipaddress} in ${ndjbdns_dir}/dnscache.conf
                                    target_file="${ndjbdns_dir}/dnscache.conf"
                                    echo "Seeding ${target_file} with useful values"
                                    sed -i -e "s/^IP=.*\$/IP=${my_ipaddress}/g" "${target_file}" > /dev/null 2>&1
        
                                    # Put our subnet in ${ndjbdns_dir}/ip
                                    target_dir="${ndjbdns_dir}/ip"
                                    echo "Seeding ${target_dir} with useful values"
                                    my_subnet=$(ifconfig ${my_eth_device} 2> /dev/null | awk -F':' '/Mask:/ {print $NF}')
                                    let counter=0
        
                                    for i in $(echo "${my_subnet}" | sed -e 's/\./\ /g') ; do
                                        let counter=${counter}+$(echo "${i}" | egrep -c 255)
                                    done
        
                                    ip_range=""
        
                                    case ${counter} in
        
                                        3)
                                            ip_range=$(echo "${my_ipaddress}" | awk -F'.' '{print $1 "." $2 "." $3}')
                                        ;;
        
                                        2)
                                            ip_range=$(echo "${my_ipaddress}" | awk -F'.' '{print $1 "." $2}')
                                        ;;
        
                                        1)
                                            ip_range=$(echo "${my_ipaddress}" | awk -F'.' '{print $1}')
                                        ;;
        
                                    esac
        
                                    if [ "${ip_range}" != "" ]; then
                                        touch "${target_dir}/${ip_range}"
                                    fi
        
                                    # Fix /etc/sysconfig/network
                                    target_file="/etc/sysconfig/network"
                                    echo "Seeding ${target_file} with useful values"
                                    my_hostname=$(hostname)
                                    my_gateway=$(route -n 2> /dev/null | egrep "eth[0-9]$" | awk '{print $2}' | egrep -v "^0")
                                    echo "NETWORKING=yes"           > "${target_file}"
                                    echo "HOSTNAME=${my_hostname}" >> "${target_file}"
                                    echo "GATEWAY=${my_gateway}"   >> "${target_file}"
        
                                    # Start dnscache and tinydns services
                                    for service in dnscache tinydns ; do
                                        service ${service} start #> /dev/null 2>&1
                                        let return_code=${return_code}+${?}
                                    done
        
                                fi

                            fi
        
                            if [ ${return_code} -eq ${SUCCESS} ]; then

                                case ${scm_branch} in

                                    dev)
                                        cd "${working_dir}/${scm_repo}" 
                                        echo "Testing DNS entries against this DNS service instance"
                                        echo "PWD: $(pwd)"
                                        make tinydns-test #> /dev/null 2>&1
                                        let return_code=${return_code}+${?}
        
                                        if [ ${return_code} -eq ${SUCCESS} ]; then
                                            # Merge ${scm_branch} branch into master
                                            ${my_git} checkout master                                                                    &&
                                            ${my_git} fetch --all                                                                        &&
                                            ${my_git} pull --all                                                                         &&
                                            echo "    Merging ${scm_branch} into master"                                                 &&
                                            ${my_git} merge ${scm_branch} -m "BAMBOO: merged vaildated ${scm_branch} branch into master" &&
                                            echo "    Pushing to master branch on STASH"                                                 &&
                                            ${my_git} push --all       
                                            let return_code=${return_code}+${?}
                                        fi

                                    ;;

                                esac

                            else
                                err_msg="Failed to start TinyDNS service"
                                return_code=${ERROR}
                            fi
        
                        else
                            echo "    ERROR:  Both \"\${lab_dns_domain}\" and \"\${lab_arpa_range}\" must be defined"
                            return_code=${ERROR}
                        fi
        
                    else
                        echo "    ERROR:  Git checkout of \"${scm_repo}\" branch \"${scm_branch}\" failed"
                        return_code=${ERROR}
                    fi
        
                else
                    echo "    ERROR:  Git clone of \"${scm_url}\" failed"
                    return_code=${ERROR}
                fi

            else
                echo "    ERROR:  Directory \"${ndjbdns_dir}\" not found"
                return_code=${ERROR}
            fi
        
        else
            echo "    ERROR:  Command \"git\" not found"
            return_code=${ERROR}
        fi

    else
        echo "    ERROR:  SSH key environment variables are undefined"
        return_code=${ERROR}
    fi

fi

if [ ${return_code} -eq ${SUCCESS} ]; then
    exit_code=${SUCCESS}
    msg="PASS"
fi

if [ "${scm_branch}" != "master" ]; then
    echo "${msg}"
else

    if [ "${msg}" = "PASS" ]; then

        # Hack for docker container persistence when called with arg "master"
        while [ 0 -eq 0 ]; do
            sleep 600
        done

    fi

fi

exit ${exit_code}
