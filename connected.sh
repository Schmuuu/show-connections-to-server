#!/bin/bash

# the following lines are used to discover the local IP addresses to filter them later from output

interface="enp1s0"
dnsresolver="9.9.9.9"

# comment the following lines if you don't want to filter anything
ip6addr=`ip -6 addr show dev ${interface} | grep 'scope global' | grep -oE "([a-fA-F0-9]+:+[a-fA-F0-9]+)+"`
ip4addr=`ip -4 addr show dev ${interface} | grep 'scope global' | awk '{ print $2 }' | sed 's|/[0-9]*||'`
gateway=`echo $ip4addr | sed "s/\`echo $ip4addr | awk -NF. '{print $4}'\`/1/"`

showAll=true
noHeader=false

for ((i=1;i<=$#;i++)); do
    if [ "${!i}" = "--http" ]; then
      #((i++))
      useHTTP=true
      showAll=false

    elif [ "${!i}" = "--ssh" ]; then
      #((i++))
      useSSH=true
      showAll=false

    elif [ "${!i}" = "--dns" ]; then
      #((i++))
      useDNS=true
      showAll=false
    elif [ "${!i}" = "--no-header" ]; then
      noHeader=true
    fi
done

headerecho()
{
  if [[ $noHeader == false ]]; then
    echo -e "\n------ $1 ------"
  fi
}

getIP()
{
  echo $1 | sed 's/:[0-9]*$//' | sed 's/[][]//g'
}

getPort()
{
  echo $1 | sed 's/.*:\([0-9]*\)$/\1/'
}

if [[ $useHTTP == true || $showAll == true ]]; then
  headerecho "HTTP(S) connections"

  while IFS= read -r LINE
  do
        if [[ "$LINE" =~ "[::]" || "$LINE" =~ "0.0.0.0" || "$LINE" =~ "*:*" ]]; then
                continue
        fi

        read -a ARRAY <<< ${LINE}

        LOCALADDR=`getIP ${ARRAY[4]}`
        LOCALPORT=`getPort ${ARRAY[4]}`
        PEERADDR=`getIP ${ARRAY[5]}`
        PEERPORT=`getPort ${ARRAY[5]}`
        PROCESS="${ARRAY[6]}"
        if [ -n "$PROCESS" ]; then
            PIDS=$(echo $PROCESS | grep -oE "pid=[0-9]+" | grep -oE "[0-9]+")
            PROCESSDETAILS=$(for PID in $PIDS; do proc=$(ps -ef | grep "$PID" | grep -v "grep" | sed 's/  */ /g' | cut -d' ' -f8-); echo -n "$proc, "; done)
            PROCESSDETAILS=$(echo $PROCESSDETAILS | sed 's/, *$//')
        else
            PROCESSDETAILS=""
        fi

        LOCALADDR=`echo $LOCALADDR | sed 's/::ffff://g'`
        PEERADDR=`echo $PEERADDR | sed 's/::ffff://g'`

        printf '%-10s \t%s:%-5s \t%-40s \t%-40s \t%s\n' "${ARRAY[1]}" "$LOCALPORT" "$PEERPORT" "$LOCALADDR" "$PEERADDR" "$PROCESSDETAILS"

  done < <(ss -panH '( dport = :https or sport = :https or dport = :http or sport = :http )')
fi

if [[ $useSSH == true || $showAll == true ]]; then
  headerecho "SSH connections"

  while IFS= read -r LINE
  do
        if [[ "$LINE" =~ "[::]" || "$LINE" =~ "0.0.0.0" || "$LINE" =~ "*:*" ]]; then
                continue
        fi

        read -a ARRAY <<< ${LINE}

        LOCALADDR=`getIP ${ARRAY[4]}`
        LOCALPORT=`getPort ${ARRAY[4]}`
        PEERADDR=`getIP ${ARRAY[5]}`
        PEERPORT=`getPort ${ARRAY[5]}`
        PROCESS="${ARRAY[6]}"
        if [ -n "$PROCESS" ]; then
            PID=$(echo $PROCESS | grep -oE "pid=[0-9]+" | grep -oE "[0-9]+" | tail -1)
            PROCESSDETAILS=$(ps -ef | grep $PID | grep -v "grep" | sed 's/  */ /g' | awk '{print substr($0, index($0,$8)) "; "}')
            PROCESSDETAILS=$(for proc in $PROCESSDETAILS; do echo -n "$proc "; done)
            PROCESSDETAILS=$(echo $PROCESSDETAILS | sed 's/\; *$//')
        else
            PROCESSDETAILS=""
        fi

        LOCALADDR=`echo $LOCALADDR | sed 's/::ffff://g'`
        PEERADDR=`echo $PEERADDR | sed 's/::ffff://g'`

        printf '%-10s \t%s:%-5s \t%-40s \t%-40s \t%s\n' "${ARRAY[1]}" "$LOCALPORT" "$PEERPORT" "$LOCALADDR" "$PEERADDR" "$PROCESSDETAILS"

  done < <(ss -panH '( dport = :ssh or sport = :ssh )')
fi

if [[ $useDNS == true || $showAll == true ]]; then
  headerecho "DNS connections"

  while IFS= read -r LINE
  do
        if [[ "$LINE" =~ "[::]" || "$LINE" =~ "0.0.0.0" || "$LINE" =~ "*:*" ]]; then
                continue
        fi

        read -a ARRAY <<< ${LINE}

        LOCALADDR=`getIP ${ARRAY[4]}`
        LOCALPORT=`getPort ${ARRAY[4]}`
        PEERADDR=`getIP ${ARRAY[5]}`
        PEERPORT=`getPort ${ARRAY[5]}`
        PROCESS="${ARRAY[6]}"
        if [ -n "$PROCESS" ]; then
            PID=$(echo $PROCESS | grep -oE "pid=[0-9]+" | grep -oE "[0-9]+")
            PROCESSDETAILS=$(ps -ef | grep "$PID" | grep -v "grep" | sed 's/  */ /g' | cut -d' ' -f8- )
        else
            PROCESSDETAILS=""
        fi

        LOCALADDR=`echo $LOCALADDR | sed 's/::ffff://g'`
        PEERADDR=`echo $PEERADDR | sed 's/::ffff://g'`

        if [[ $PEERADDR == $dnsresolver ]] || [[ $LOCALADDR == $ip4addr && $PEERADDR == $ip4addr ]]; then continue; fi

        printf '%-10s \t%s:%-5s \t%-40s \t%-40s \t%s\n' "${ARRAY[1]}" "$LOCALPORT" "$PEERPORT" "$LOCALADDR" "$PEERADDR" "$PROCESSDETAILS"

  done < <(ss -panH '( dport = :53 or sport = :53 )')
fi

printf "\n"

exit 0
