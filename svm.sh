#/bin/bash -x
# SBT Version Manager
# Bash function for managing SBT versions 
# 
# This started off as a fork of the excellent 
# Play! Framework Version Manager (https://github.com/kaiinkinen/svm)
# forked from NVM by Kai Inkinen <kai.inkinen@gmail.com>
#
# Auto detect the SVM_DIR
DEBUG=false

if [ ! -d "${SVM_DIR}" ]; then
    export SVM_DIR=$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)
fi

ALIAS_DIR_NAME=alias
INSTALL_DIR_NAME=install
SRC_DIR_NAME=src
export SVM_INSTALL_DIR=${SVM_DIR}/${INSTALL_DIR_NAME}

ensure_directories() 
{
    mkdir -p ${SVM_DIR}/{${INSTALL_DIR_NAME},${ALIAS_DIR_NAME},${SRC_DIR_NAME}}
}

# Download the file
download_file_if_needed() 
{
    url=$1
    file=$2
    file_http_head=${file}.http_head
    
    tempfile=$(TEMPDIR=/tmp && mktemp -t svm_curl.XXXXXX)

    echo -en "Checking download url ${url} ..."
    
    # What's currently on the server?
    http_code=$(curl -w '%{http_code}' -sIL "${url}" -o ${tempfile})
    if (( $? != 0 || ${http_code} != 200 )); then 
        echo -e "\tdownload failed with status ${http_code}"
        rm -f ${tempfile}
        return 10
    fi

    if [ ! -f ${file_http_head} ]; then 
        cp -f ${tempfile} ${file_http_head}
    fi

    echo -e "\tSuccess!\n\nStarting the download"

    if [ -f $file ]; then 
        $DEBUG && echo "Getting file size stats for '${file}':"'stat -f %z ${file})'
        actual_file_length=$(stat -f '%z' ${file})
        $DEBUG && echo "File size is ${actual_file_length}"

        if [ -f ${file_http_head} ] ; then 
            $DEBUG && echo "Head file exists"

            # Downloaded by svm, lines terminated by \r\n, so we need to take some precautions
            etag=$(grep 'ETag' ${file_http_head} | cut -d \" -f 2 || '0')
            content_length=$(grep 'Content-Length' ${file_http_head} | awk '{sub("\r",""); print $2}' || 0)
            
            # Current head
            previous_etag=$(grep 'ETag' ${tempfile} | cut -d \" -f 2 || '0')

            $DEBUG && echo "Checking file ($file) whether etags match ('${etag}' and '${previous_etag}') and content lengths match ('${content_length}' and '${actual_file_length}')"

            if [[ "${etag}" == "${previous_etag}" && "$content_length" -eq "$actual_file_length" ]]; then 
                echo -e "\nFile '${file}' already downloaded and valid. Using cached version\n"
                return 0;
            elif [[ "${etag}" != "${previous_etag}" ]]; then 
                rm -f ${file}
                
            elif [ "$content_length" -gt "$actual_file_length" ]; then 
                # Still in progress
                echo > /dev/null
            else
                # Something fishy here, just redownload
                rm -f ${file}
            fi
                
            curl -C - --progress-bar ${url} -o "${file}" || \
                (echo -e "\nRestart download" && rm -f "${file}" && curl --progress-bar ${url} -o "${file}" ) || \
                mv ${tempfile} ${file_http_head} && return 0 # Success

            return 255 # fail
           
        fi
    fi

    # No file. Just download
    curl -C - --progress-bar ${url} -o "${file}" || \
        (echo -e "\Restart download" &&  $rm -f "${file}" && curl --progress-bar ${url} -o "${file}" ) || \
        mv ${tempfile} ${file_http_head} && return 0 # Success
    
    return 255 # fail
}

# Expand a version using the version cache
svm_version()
{
    PATTERN=$1
    # The default version is the current one
    if [ ! "${PATTERN}" ]; then
        PATTERN='current'
    fi

    VERSION=$(svm_ls $PATTERN | tail -n1)
    echo "${VERSION}"
    
    if [ "${VERSION}" = 'N/A' ]; then
        return 13
    fi
}

svm_ls()
{
    PATTERN=$1
    VERSIONS=''
    
    ensure_directories

    if [ "${PATTERN}" = 'current' ]; then
        echo $SVM_CURRENT_VERSION
        return
    fi

    if [ -f "${SVM_DIR}/alias/${PATTERN}" ]; then
        svm_version $(cat ${SVM_DIR}/alias/${PATTERN})
        return
    fi

    # If it looks like an explicit version, don't do anything funny
    if [[ "${PATTERN}" == ?*.?* ||
		"${PATTERN}" == ?*.?*.?* ]]; then
        VERSIONS="${PATTERN}"
    else
	if [ -z "${PATTERN}" ]; then 
	    PATTERN="?*."
	fi

        VERSIONS=$((cd ${SVM_INSTALL_DIR} && ls -1 -d ${PATTERN}* 2>/dev/null) | sort -t. -k 1,1n -k 2,2n)
    fi
    if [ ! "${VERSIONS}" ]; then
        echo "N/A"
        return
    fi
    echo "${VERSIONS}"
    return
}

print_versions()
{
    OUTPUT=''
    for VERSION in $1; do
        PADDED_VERSION=$(printf '%10s' ${VERSION})
        if [[ -d "${SVM_INSTALL_DIR}/${VERSION}" ]]; then
            PADDED_VERSION="\033[0;32m${PADDED_VERSION}\033[0m" 
        fi
        OUTPUT="${OUTPUT}\n${PADDED_VERSION}" 
    done
    echo -e "${OUTPUT}" | column 
}

svm()
{
    if [ $# -lt 1 ]; then
	svm help
	return
    fi
    case $1 in
	"help" )
	    echo
	    echo "SBT Version Manager"
	    echo
	    echo "Usage:"
	    echo "    svm help                    Show this message"
	    echo "    svm install <version>       Download and install a <version>"
	    echo "    svm uninstall <version>     Uninstall a version"
	    echo "    svm use <version>           Modify PATH to use <version>"
	    echo "    svm run <version> [<args>]  Run <version> with <args> as arguments"
	    echo "    svm ls                      List installed versions"
	    echo "    svm ls <version>            List versions matching a given description"
	    echo "    svm deactivate              Undo effects of SVM on current shell"
	    echo "    svm alias [<pattern>]       Show all aliases beginning with <pattern>"
	    echo "    svm alias <name> <version>  Set an alias named <name> pointing to <version>"
	    echo "    svm unalias <name>          Deletes the alias named <name>"
	    echo "    svm clean                   Removes non-installed versions from the cache"
	    echo "    svm clear-cache             Deletes all cached zip files"
	    echo
	    echo "Example:"
	    echo "    svm install 0.11.2          Install a specific version number"
	    echo "    svm use 0.12                Use the latest available 0.12.x release"
	    echo "    svm alias default 0.13      Auto use the latest installed 0.13.x version"
	    echo
	    ;;
	"install" )
	    if [ ! $(which curl) ]; then
		echo 'SVM Needs curl to proceed.' >&2;
	    fi
	    
	    if [ $# -ne 2 ]; then
		svm help
		return
	    fi

	    ensure_directories
	    VERSION=$(svm_version $2)

	    [ -d "${SVM_DIR}/${VERSION}" ] && echo "${VERSION} is already installed." && return

	    appname=sbt
	    zipfile="${appname}.zip"
            zipfile_location=${SVM_DIR}/${SRC_DIR_NAME}/${zipfile}
            
	    MAJOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 1)
	    MINOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 2)
            
            return_code=255
            cd "${SVM_DIR}" 
            for download_url in "http://repo.scala-sbt.org/scalasbt/sbt-native-packages/org/scala-sbt/sbt/${VERSION}/${zipfile}"; do 
                $DEBUG && echo "download_file_if_needed '$download_url' '$zipfile_location'"
                download_file_if_needed $download_url $zipfile_location
                if (( $? == 0)); then 
                    return_code=0
                    break
                fi
            done

	    if (( $return_code != 0 )); then 
		echo -e "\nCannot download version ${VERSION} of "'SBT'" None of the configured download URLs worked"
		return 1
	    fi

	    if (cd $(TEMPDIR=/tmp && mktemp -d -t svm.XXXXXX) && \
                unzip -u -qq "${zipfile_location}" && \
                rm -rf ${SVM_INSTALL_DIR}/${VERSION} && \
	        mv -f ${appname} ${SVM_INSTALL_DIR}/${VERSION})
	    then
		svm use ${VERSION}
		if [ ! -f "${SVM_DIR}/${ALIAS_DIR_NAME}/default" ]; then 
		    # Set this as default, as we currently don't have one
		    echo "No default installation selected. Using ${VERSION}"
		    mkdir -p "${SVM_DIR}/${ALIAS_DIR_NAME}"
		    svm alias default ${VERSION}
		fi

	    else
		echo "svm: install ${VERSION} failed!"
	    fi
	    ;;
	"uninstall" )
	    [ $# -ne 2 ] && svm help && return
	    if [[ $2 == $(svm_version) ]]; then
		echo "svm: Cannot uninstall currently-active SBT version, $2."
		return
	    fi
	    VERSION=$(svm_version $2)
	    if [ ! -d ${SVM_INSTALL_DIR}/${VERSION} ]; then
		echo "SBT version ${VERSION} is not installed yet"
		return;
	    fi

            # Delete all files related to target version
	    (cd "${SVM_DIR}" && \
		( [ -d ${INSTALL_DIR_NAME}/${VERSION} ] && echo "Removing installed version at '${SVM_DIR}/${INSTALL_DIR_NAME}/${VERSION}'" && rm -rf "${INSTALL_DIR_NAME}/${VERSION}" 2>/dev/null ) ; \
		( [ -f sbt.zip ] && rm -f "sbt.zip*" 2>/dev/null ) ; \
		( [ -f src/sbt.zip ] && echo "Removing downloaded zip at '${SVM_DIR}/src/sbt.zip'" && rm -f src/sbt.zip* 2>/dev/null ))
	    echo "Uninstalled SBT ${VERSION}"
	    
           # Rm any aliases that point to uninstalled version.
	    for A in $(grep -l ${VERSION} ${SVM_DIR}/${ALIAS_DIR_NAME}/*)
	    do
		svm unalias $(basename $A)
	    done

	    ;;
	"deactivate" )
	    if [[ $PATH == *${SVM_DIR}/* ]]; then
		export PATH=${PATH%${SVM_DIR}/*}${PATH#*${SVM_DIR}/*:}
		hash -r
		echo "${SVM_DIR}/* removed from \$PATH"
	    else
		echo "Could not find ${SVM_DIR}/* in \$PATH"
	    fi
	    ;;
	"use" )
	    if [ $# -ne 2 ]; then
		svm help
		return
	    fi
	    VERSION=$(svm_version $2)
	    if [ ! -d ${SVM_INSTALL_DIR}/${VERSION} ]; then
		echo "${VERSION} version is not installed yet"
		return;
	    fi
	    if [[ $PATH == *${SVM_INSTALL_DIR}/* ]]; then
		PATH=${PATH%${SVM_INSTALL_DIR}/*}${PATH#*${PVM_DIR}/*:} 
	    fi
	    export PATH="${SVM_INSTALL_DIR}/${VERSION}:$PATH"
	    hash -r
	    export SVM_PATH="${PVM_INSTALL_DIR}/${VERSION}"
	    export SVM_BIN="${PVM_INSTALL_DIR}/${VERSION}"
	    export SVM_CURRENT_VERSION=${VERSION}

	    echo "Now using SBT ${VERSION}"
	    ;;
#	"run" )
#      # run given version of SBT
#	    if [ $# -lt 2 ]; then
#		svm help
#		return
#	    fi
#	    VERSION=$(svm_version $2)
#	    if [ ! -d ${SVM_DIR}/${VERSION} ]; then
#		echo "${VERSION} version is not installed yet"
#		return;
#	    fi
#	    echo "Running SBT ${VERSION}"
#	    ${SVM_DIR}/${VERSION}/bin/sbt "${@:3}"
#	    ;;
	"ls" | "list" )
	    echo "Available:"
	    print_versions "$(svm_ls $2)"
	    if [ $# -eq 1 ]; then
		echo -e "\nAliases:"
		svm alias 
		echo -ne "\nCurrent version: \ncurrent -> "; svm_version current
		echo 
	    fi
	    return
	    ;;
	"alias" )
	    ensure_directories
	    if [ $# -le 2 ]; then
		(cd ${SVM_DIR}/${ALIAS_DIR_NAME} && for ALIAS in $(\ls $2* 2>/dev/null); do
			DEST=$(cat $ALIAS)
			VERSION=$(svm_version $DEST)
			if [ "$DEST" = "${VERSION}" ]; then
			    echo -e "${ALIAS} -> ${DEST}"
			else
			    echo -e "${ALIAS} -> ${DEST} (-> ${VERSION})"
			fi
			done)
		return
	    fi
	    if [ ! "$3" ]; then
		rm -f ${SVM_DIR}/${ALIAS_DIR_NAME}/$2
		echo "$2 -> *poof*"
		return
	    fi
	    mkdir -p ${SVM_DIR}/${ALIAS_DIR_NAME}
	    VERSION=$(svm_version $3)
	    if [ $? -ne 0 ]; then
		echo "! WARNING: Version '$3' does not exist." >&2
	    fi
	    echo $3 > "${SVM_DIR}/${ALIAS_DIR_NAME}/$2"
	    if [ ! "$3" = "${VERSION}" ]; then
		echo "$2 -> $3 (-> ${VERSION})"
	    else
		echo "$2 -> $3"
	    fi
	    ;;
	"unalias" )
	    ensure_directories
	    [ $# -ne 2 ] && svm help && return
	    [ ! -f ${SVM_DIR}/${ALIAS_DIR_NAME}/$2 ] && echo "Alias $2 doesn't exist!" && return
	    rm -f ${SVM_DIR}/${ALIAS_DIR_NAME}/$2
	    echo "Deleted alias $2"
	    ;;
#    "copy-packages" )
#        if [ $# -ne 2 ]; then
#          svm help
#          return
#        fi
#        VERSION=$(svm_version $2)
#        ROOT=$(svm use ${VERSION} && spm -g root)
#        INSTALLS=$(svm use ${VERSION} > /dev/null && spm -g -p ll | grep "$ROOT\/[^/]\+$" | cut -d '/' -f 8 | cut -d ":" -f 2 | grep -v spm | tr "\n" " ")
#        npm install -g $INSTALLS
#    ;;
	"clear-cache" )
            rm -f ${SVM_DIR}/src/sbt.zip* 2>/dev/null
            echo "Cache cleared."
	    ;;
        "clean" )
	    rm -f ${SVM_DIR}/src/sbt.zip* 2>/dev/null
            echo "Cleaned."
            ;;
	"version" )
            print_versions "$(svm_version $2)"
	    ;;
	* )
	    svm help
	    ;;
    esac
}

svm ls default >/dev/null 2>&1 && svm use default >/dev/null
