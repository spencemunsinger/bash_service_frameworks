function linuxAptRequirements {
    echo -en " \n     ${FUNCNAME[0]} "
    # $1 arg is the os_cmd, "yum" or "apt"
    os_cmd="${1}"
    # gnupg
    if [[ -z "$(command -v gpg)" ]]; then

        debugOutput "${FUNCNAME[0]}: gnupg not found, installing..."

        sudo ${os_cmd} install gnupg -y
        # verify gnupg
        if [[ -z "$(command -v gpg)" ]]; then
            errorOut "${FUNCNAME[0]}: gnupg not found after install"
            exit 1
        else

            debugOutput "${FUNCNAME[0]}: gnupg found, good to go"

        fi
    else

        debugOutput "${FUNCNAME[0]}: gnupg found, good to go"

    fi
    # ssh-keygen
    if [[ -z "$(command -v ssh-keygen)" ]]; then

        debugOutput "${FUNCNAME[0]}: ssh-keygen not found, installing..."

        if [[ "${os_cmd}" == "yum" ]]; then
            package="openssh-clients"
        elif [[ "${os_cmd}" == "apt" ]]; then
            package="openssh-client"
        fi
        sudo ${os_cmd} install ${package} -y
         # verify ssh-keygen
        if [[ -z "$(command -v ssh-keygen)" ]]; then
            errorOut "${FUNCNAME[0]}: ssh-keygen not found after install"
        else

            debugOutput "${FUNCNAME[0]}: ssh-keygen found, good to go"

        fi
    else

        debugOutput "${FUNCNAME[0]}: ssh-keygen found, good to go"

    fi
     # awscli check for binary... if not found, install
    if [[ -z "$(command -v aws)" ]]; then

        debugOutput "${FUNCNAME[0]}: awscli not found, installing..."

        sudo ${os_cmd} install awscli -y
        # verify awscli...
        if [[ -z "$(command -v aws)" ]]; then
            errorOut "${FUNCNAME[0]}: awscli not found after install"
        else

            debugOutput "${FUNCNAME[0]}: awscli found, good to go"

        fi
    else

        debugOutput "${FUNCNAME[0]}: awscli found, good to go"

    fi
    # check for jq...
    if [[ -z "$(command -v jq)" ]]; then

        debugOutput "${FUNCNAME[0]}: jq not found, installing..."

        sudo ${os_cmd} install jq -y
        # verify jq
        if [[ -z "$(command -v jq)" ]]; then
            errorOut "${FUNCNAME[0]}: jq not found after install"
        else

            debugOutput "${FUNCNAME[0]}: jq found, good to go"

        fi
    else

        debugOutput "${FUNCNAME[0]}: jq found, good to go"

    fi

    debugOutput "${FUNCNAME[0]}: linux binaries are setup..."

}

function macosRequirements {
    echo -en " \n     ${FUNCNAME[0]} "
    debugOutput "${FUNCNAME[0]}: starting MacOS setup" 
    # check for homebrew... if not found, ask to install
    if [[ -z "$(command -v brew)" ]]; then

      debugOutput "${FUNCNAME[0]}: homebrew not found..."

      read -r -p "Press enter to install homebrew, or \"ctrl-c\" to exit"

      debugOutput "${FUNCNAME[0]}: installing homebrew..."

      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # verify homebrew
      if [[ -z "$(command -v brew)" ]]; then
        errorOut "${FUNCNAME[0]}: homebrew not found after install"
      else

        debugOutput "${FUNCNAME[0]}: homebrew found, good to go"

      fi
    else

      debugOutput "${FUNCNAME[0]}: homebrew found, good to go"

    fi
    # gnupg check for binary... if not found, install
    if [[ -z "$(command -v gpg)" ]]; then

      debugOutput "${FUNCNAME[0]}: gnupg not found..."

      read -r -p "Press enter to install gnupg through homebrew, or \"ctrl-c\" to exit"

      debugOutput "${FUNCNAME[0]}: installing gnupg..."

      brew install gnupg
      # verify gnupg
      if [[ -z "$(command -v gpg)" ]]; then
        errorOut "${FUNCNAME[0]}: gnupg not found after install"
      else

        debugOutput "${FUNCNAME[0]}: gnupg found, good to go"

      fi
    else

      debugOutput "${FUNCNAME[0]}: gnupg found, good to go"

    fi
    # ssh-keygen check for binary... if not found, install
    if [[ -z "$(command -v ssh-keygen)" ]]; then

      debugOutput "${FUNCNAME[0]}: ssh-keygen not found..."

      read -r -p "Press enter to install ssh-keygen through homebrew, or \"ctrl-c\" to exit"
      brew install openssh
      # verify ssh-keygen
      if [[ -z "$(command -v ssh-keygen)" ]]; then
        errorOut "${FUNCNAME[0]}: ssh-keygen not found after install"
      else

        debugOutput "${FUNCNAME[0]}: ssh-keygen found, good to go"

      fi
    else

      debugOutput "${FUNCNAME[0]}: ssh-keygen found, good to go"

    fi
    # awscli check for binary... if not found, install
    if [[ -z "$(command -v aws)" ]]; then

      debugOutput "${FUNCNAME[0]}: awscli not found..."

      read -r -p "Press enter to install awscli through homebrew, or \"ctrl-c\" to exit"

      debugOutput "${FUNCNAME[0]}: installing awscli..."

      brew install awscli
      # verify awscli
      if [[ -z "$(command -v aws
      )" ]]; then
        errorOut "${FUNCNAME[0]}: awscli not found after install"
      else

        debugOutput "${FUNCNAME[0]}: awscli found, good to go"

      fi
    else

      debugOutput "${FUNCNAME[0]}: awscli found, good to go"

    fi
    # shred (core-utils) check for binary... if not found, install
    if [[ -z "$(command -v shred)" ]]; then

      debugOutput "${FUNCNAME[0]}: shred not found..."

      read -r -p "Press enter to install shred through homebrew, or \"ctrl-c\" to exit"

      debugOutput "${FUNCNAME[0]}: installing shred..."

      brew install coreutils
      # verify shred
      if [[ -z "$(command -v shred)" ]]; then
        errorOut "${FUNCNAME[0]}: shred not found after install"
      else

        debugOutput "${FUNCNAME[0]}: shred found, good to go"

      fi
    else

      debugOutput "${FUNCNAME[0]}: shred found, good to go"

    fi
    # jq check for binary... if not found, install
    if [[ -z "$(command -v jq)" ]]; then

      debugOutput "${FUNCNAME[0]}: jq not found..."

      read -r -p "Press enter to install jq through homebrew, or \"ctrl-c\" to exit"

      debugOutput "${FUNCNAME[0]}: installing jq..."

      brew install jq
      # verify jq
      if [[ -z "$(command -v jq)" ]]; then
        errorOut "${FUNCNAME[0]}: jq not found after install"
      else

        debugOutput "${FUNCNAME[0]}: jq found, good to go"

      fi
    else

      debugOutput "${FUNCNAME[0]}: jq found, good to go"

    fi

    debugOutput "${FUNCNAME[0]}: MacOS binaries are setup..."

}

function checkAwsTokenValidity() {
    echo -en " \n     ${FUNCNAME[0]} "
    # Temporarily capture the output and error of the aws command
    local output
    output=$(aws sts get-caller-identity 2>&1)
    local status=$?
    local newline=$'\n' # Define a variable containing a newline character
    # return result
    if [ $status -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

function createWorkingDirs() {
  echo -en " \n     ${FUNCNAME[0]} "
  # source conf file again to get environment specific variables
  # create ${SFTP_DIR} directory
  if [[ -z "${SFTP_DIR}" ]]; then
    errorOut "${FUNCNAME[0]}: SFTP_DIR is not set"
  fi
  if [[ -z "${PGP_DIR}" ]]; then
    errorOut "${FUNCNAME[0]}: PGP_DIR is not set"
  fi
  if [[ -z "${ACTIVATE_DIR}" ]]; then
    errorOut "${FUNCNAME[0]}: ACTIVATE_DIR is not set"
  fi 
  if [[ -z "${TRANSPORT_DIR}" ]]; then
    errorOut "${FUNCNAME[0]}: TRANSPORT_DIR is not set"
  fi
  if [[ ! -d "${SFTP_DIR}" ]]; then

    debugOutput "${FUNCNAME[0]}: creating ${SFTP_DIR} directory..."

    mkdir -p "${SFTP_DIR}"
    chmod 700 "${SFTP_DIR}"

    debugOutput "${FUNCNAME[0]}: ${SFTP_DIR} directory created"

  else

    debugOutput "${FUNCNAME[0]}: ${SFTP_DIR} directory exists"

    local filesInSFTPDir=$(find "${SFTP_DIR}" -type f| wc -l)
    if [[ "${filesInSFTPDir}" -gt 0 ]]; then

      debugOutput "${FUNCNAME[0]}: WARNING: ${SFTP_DIR} directory is not empty"
      debugOutput "${FUNCNAME[0]}: WARNING: files in ${SFTP_DIR} will be removed"

      rm -rf "${SFTP_DIR}"/*

      debugOutput "${FUNCNAME[0]}: files removed from ${SFTP_DIR}"

    fi
  fi
  # pgp directory
  if [[ ! -d "${PGP_DIR}" ]]; then

    debugOutput "${FUNCNAME[0]}: creating ${PGP_DIR} directory..."

    mkdir -p "${PGP_DIR}"
    chmod 700 "${PGP_DIR}"

    debugOutput "${FUNCNAME[0]}: ${PGP_DIR} directory created"

  else

    debugOutput "${FUNCNAME[0]}: ${PGP_DIR} directory exists"

    local filesInPGPDir=$(find "${PGP_DIR}" -type f| wc -l)
    if [[ "${filesInPGPDir}" -gt 0 ]]; then

      debugOutput "${FUNCNAME[0]}: WARNING: ${PGP_DIR} directory is not empty"
      debugOutput "${FUNCNAME[0]}: WARNING: files in ${PGP_DIR} will be removed"

      rm -rf "${PGP_DIR}"/*

      debugOutput "${FUNCNAME[0]}: files removed from ${PGP_DIR}"

    fi
  fi
  # create activation directory
  if [[ ! -d "${ACTIVATE_DIR}" ]]; then

    debugOutput "${FUNCNAME[0]}: creating ${ACTIVATE_DIR} directory..."

    mkdir -p "${ACTIVATE_DIR}"
    chmod 700 "${ACTIVATE_DIR}"

    debugOutput "${FUNCNAME[0]}: ${ACTIVATE_DIR} directory created"

  else

    debugOutput "${FUNCNAME[0]}: ${ACTIVATE_DIR} directory exists"

    local filesInActivateDir=$(find "${ACTIVATE_DIR}" -type f| wc -l)
    if [[ "${filesInActivateDir}" -gt 0 ]]; then

      debugOutput "${FUNCNAME[0]}: WARNING: ${ACTIVATE_DIR} directory is not empty"
      debugOutput "${FUNCNAME[0]}: WARNING: files in ${ACTIVATE_DIR} will be removed"

      rm -rf "${ACTIVATE_DIR}"/*

      debugOutput "${FUNCNAME[0]}: files removed from ${ACTIVATE_DIR}"

    fi
  fi
  # create transport directory
  if [[ ! -d "${TRANSPORT_DIR}" ]]; then

    debugOutput "${FUNCNAME[0]}: creating ${TRANSPORT_DIR} directory..."

    mkdir -p "${TRANSPORT_DIR}"
    chmod 700 "${TRANSPORT_DIR}"

    debugOutput "${FUNCNAME[0]}: ${TRANSPORT_DIR} directory created"

  else

    debugOutput "${FUNCNAME[0]}: ${TRANSPORT_DIR} directory exists"

    local filesInTransportDir=$(find "${TRANSPORT_DIR}" -type f| wc -l)
    if [[ "${filesInTransportDir}" -gt 0 ]]; then

      debugOutput "${FUNCNAME[0]}: WARNING: ${TRANSPORT_DIR} directory is not empty"
      debugOutput "${FUNCNAME[0]}: WARNING: files in ${TRANSPORT_DIR} will be removed"

      rm -rf "${TRANSPORT_DIR}"/*

      debugOutput "${FUNCNAME[0]}: files removed from ${TRANSPORT_DIR}"

    fi
  fi
}

function setupPgp() {
    echo -en " \n     ${FUNCNAME[0]} "

    debugOutput "setting up gpg to function, this uses the current directory"

    # copy the gpg config file into ${PGP_DIR}
    cp "${SCRIPT_DIR}/conf/${PGP_CONFIG_FILE}" "${PGP_DIR}/${PGP_CONFIG_FILE}" || errorOut "failed to copy ${PGP_CONFIG_FILE} to ${PGP_DIR}"
    cp "${SCRIPT_DIR}/conf/${PGP_AGENT_CONF}" "${PGP_DIR}/${PGP_AGENT_CONF}" || errorOut "failed to copy ${PGP_AGENT_CONF} to ${PGP_DIR}"
    # drop any lingering gpg-agent processes...
    gpgconf --kill --quiet gpg-agent >/dev/null 2>&1 || errorOut "failed to kill gpg-agent"
    sleep 5
    # start agent
    gpg-agent --homedir=${PGP_DIR} --daemon >/dev/null 2>&1 || errorOut "failed to start gpg-agent"
    # set this directory as home for gpg
    export GNUPGHOME="${PGP_DIR}"

    debugOutput "gpg home:  ${GNUPGHOME}"

}

function cleanPgpDir() {

    if [ -z ${GNUPGHOME} ]; then
        errorOut "GNUPGHOME is not set"
    else 
        if [[ -d "${GNUPGHOME}" ]]; then

            debugOutput "GNUPGHOME is set and directory exists"


        else
            errorOut "GNUPGHOME is set but directory does not exist"
        fi
    fi

    debugOutput "cleaning up the GPG directory, removing socket and keyring files, dropping agent"
    debugOutput "GNUPGHOME: ${GNUPGHOME}"

    if [ "$(pwd)" == "${GNUPGHOME}" ]; then
        cd ../ || errorOut "failed to change out of directory ${GNUPGHOME}"
    fi
    # remove any lingering gpg-agent processes...
    gpgconf --kill --quiet gpg-agent >/dev/null 2>&1  || errorOut "failed to kill gpg-agent"
    sleep 5
    # remove the socket and keyrings files (leaving ${GNUPGHOME} and conf file intact)

    debugOutput "removing socket and keyring files..."
    
    rm -rf "${GNUPGHOME}"/* || errorOut "failed to remove socket and keyring files"

    debugOutput "files removed from ${GNUPGHOME}"
    debugOutput "clean up complete"

}

function resetPgp() {
    echo -en " \n     ${FUNCNAME[0]} "
    cleanPgpDir
    setupPgp # start agent and set GNUPGHOME
}

function cleanupWorkingDirs() {
    echo -en " \n     ${FUNCNAME[0]} "

    debugOutput "${FUNCNAME[0]}: cleaning up working directories..."
    if [[ -z "${SFTP_DIR}" ]]; then
        errorOut "${FUNCNAME[0]}: SFTP_DIR is not set"
    fi
    if [[ -z "${PGP_DIR}" ]]; then
        errorOut "${FUNCNAME[0]}: PGP_DIR is not set"
    fi
    if [[ -z "${ACTIVATE_DIR}" ]]; then
        errorOut "${FUNCNAME[0]}: ACTIVATE_DIR is not set"
    fi
    if [[ -z "${TRANSPORT_DIR}" ]]; then
        errorOut "${FUNCNAME[0]}: TRANSPORT_DIR is not set"
    fi

    # remove files in ${SFTP_DIR}
    if [[ -d "${SFTP_DIR}" ]]; then

        debugOutput "${FUNCNAME[0]}: removing files in ${SFTP_DIR}..."

        rm -rf "${SFTP_DIR}"/*

        debugOutput "${FUNCNAME[0]}: files removed from ${SFTP_DIR}"

    fi
    # remove files in ${PGP_DIR}
    if [[ -d "${PGP_DIR}" ]]; then

        debugOutput "${FUNCNAME[0]}: removing files in ${PGP_DIR}..."

        rm -rf "${PGP_DIR}"/*

        debugOutput "${FUNCNAME[0]}: files removed from ${PGP_DIR}"

    fi
    # remove files in ${ACTIVATE_DIR}
    if [[ -d "${ACTIVATE_DIR}" ]]; then

        debugOutput "${FUNCNAME[0]}: removing files in ${ACTIVATE_DIR}..."

        rm -rf "${ACTIVATE_DIR}"/*

        debugOutput "${FUNCNAME[0]}: files removed from ${ACTIVATE_DIR}"

    fi
    # remove files in ${TRANSPORT_DIR}
    if [[ -d "${TRANSPORT_DIR}" ]]; then

        debugOutput "${FUNCNAME[0]}: removing files in ${TRANSPORT_DIR}..."

        rm -rf "${TRANSPORT_DIR}"/*

        debugOutput "${FUNCNAME[0]}: files removed from ${TRANSPORT_DIR}"

    fi

    debugOutput "${FUNCNAME[0]}: working directories cleaned up"

}
