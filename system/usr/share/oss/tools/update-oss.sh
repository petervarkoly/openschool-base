#!/bin/bash
ORIG=$@

usage()
{
        echo "Usage: $0 [-k] [-r reponame] [-h]

        -k      Do not install kernel updates
        -r      Install only updates from given repository
        -h      Print this page
"
}


description ()
{
        echo 'NAME:'
        echo '  update-oss.sh'
        echo 'DESCRIPTION:'
        echo '  With this script we can update the system.'
        echo 'PARAMETERS:'
        echo '  MANDATORY:'
        echo "                              : No need for mandatory parameters. (There's no need for parameters for running this script.)"
        echo '  OPTIONAL:'
        echo '          -h,   --help        : Display this help.(type=boolean)'
        echo '          -d,   --description : Display the descriptiont.(type=boolean)'
        echo '          -k                  : Do not install kernel updates.(type=boolean)'
        echo '          -r                  : Install only updates from given repository.(Ex: ./update-oss.sh -r=<reponam>)(type=string)'
        exit
}

while [ "$1" != "" ]; do
    case $1 in
        -k )                    NOKERNEL=1;;
        -r=* )                  repo=$(echo $1 | sed -e 's/-r=//g')
                                if [ "$repo" = '' ]
                                then
                                        usage
                                        exit
                                fi
                                ZARGS="$ZARGS -r $repo";;
        -d | --description )    description
                                exit;;
        -h | --help )           usage
                                exit;;
        * )                     usage
                                exit 1
    esac
    shift
done

zypper -n up $( /usr/share/oss/tools/list-updates.sh $ORIG )
