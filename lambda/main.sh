#!/usr/bin/env bash

# initial set for DEBUG here

export DEBUG="false"  # true, initial messages are present, false they are turned off
               # if -d is passed as an argument, this will be set to true following collection of getopts

# set scripting homedir
# Save the current directory
CURRENT_DIR="$(pwd)"
# Change to the script's directory and get the absolute path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Change back to the original directory
cd "$CURRENT_DIR"

source "${SCRIPT_DIR}/lib/utils.sh"  # bring in errorOut and debugOutput initial functions

debugOutput "MAIN: script dir: ${SCRIPT_DIR}"
debugOutput "MAIN: current dir: $(pwd)"

# config file
CONFFILE="${SCRIPT_DIR}/conf/bash_tools.conf"

debugOutput "MAIN: config file set to: ${CONFFILE}"
debugOutput "MAIN: starting main script..."
debugOutput "MAIN: sourcing functions"

for f in ${SCRIPT_DIR}/lib/*.sh; do

  debugOutput "MAIN: sourcing $f"

  source "$f"
done

debugOutput "MAIN: setting timestamp values"

# directly set YEAR and TIMESTAMP here
export YEAR=$(date +"%Y")
export TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# -------------------------------------------------- #
# parse args
# -------------------------------------------------- #

# Initialize variables to track if options are set
environment=false
ActivatePGPOnly=false
CreateKeysOnly=false
environment=false
Finalize=false
PGPOnly=false
SFTPOnly=false
TransmitOnly=false
DEBUG=false

echo
while getopts ":ace:fpstd" opt; do
  case ${opt} in
    a )
      # Option to activate PGP keys. This will send the activation file from secretsmanager that was generated during the createPGPKeyPair function execution
      export ActivatePGPOnly="true"
      echo "MAIN: Activating PGP keys only"
      ;;
    c )
      # Option to create keys only. This will create the PGP and SFTP keypairs and push the public keys to secretsmanager.
      export CreateKeysOnly="true"
      echo "MAIN: Creating PGP and SFTP keys only"
      ;;
    e )
      # Option to set the environment. This will set the SFTP_HOST variable to the appropriate value for the environment.
      case $OPTARG in 
        "playground")
          export environment="${OPTARG}"
          export toastEnvironment="${OPTARG}"
          ;;
        "uat")
          export environment="${OPTARG}"
          export toastEnvironment="preproduction"
          ;;
        "preproduction")
          export environment="${OPTARG}"
          export toastEnvironment="${OPTARG}"
          ;;
        "prod")
          export environment="${OPTARG}"
          export toastEnvironment="${OPTARG}"
          ;;
        *)
          echo
          echo "ERROR: Environment not recognized"
          Usage 1
         ;;
      esac
      echo "MAIN:  environment submitted:  ${environment}"
      ;;
    f )
      # Option to finalize. This will promote the public keys to the active keys in secretsmanager.
      export Finalize="true"
      echo "MAIN: Finalizing keys (promoting candidate key to active).  This will be PGP or SFTP only..."
      ;;
    p )
      # Option to set PGP only. This will only create the PGP keypair and push the public and private keys to secretsmanager.
      export PGPOnly="true"
      echo "MAIN: operating on PGP key(s) only"
      ;;
    s )
      # Option to set SFTP only. This will only create the SFTP keypair and push the public and private keys to secretsmanager.
      export SFTPOnly="true"
      echo "MAIN: operating on SFTP key(s) only"
      ;;
    t )
      # Option to transmit only. This will sign the public keys and transmit them to Chase. No keys will be created or pushed to secrets manager with this option.
      export TransmitOnly="true"
      echo "MAIN: Transmitting keys only"
      ;;
    h )
      Usage
      ;;
    d )
      export DEBUG="true"
      echo "MAIN: Debugging enabled"
      ;;
    \? )
      echo "Invalid option: $OPTARG"
      Usage 1

      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument"
      Usage 1

      ;;
  esac
done

# check for required -e option
if [ "$environment" == "false" ]; then
  echo
  echo "ERROR: Environment is required!"
  Usage 1
fi

# Check if only -e was provided and no other options
if [ -n "$environment" ] && ! $ActivatePGPOnly && ! $CreateKeysOnly && ! $Finalize && ! $PGPOnly && ! $SFTPOnly && ! $TransmitOnly; then
  # Handle default behavior for -e option only
  echo
  echo "MAIN: Environment was the only arg supplied..."
  echo "      Default behavior is to create and transmit both PGP and SFTP keys..."
fi

# only -s OR -p never both
if $SFTPOnly && $PGPOnly; then
  echo "ERROR: Cannot specify both -s (SFTPOnly) and -p (PGPOnly) options together."
  Usage 1
fi

# start progress dots if debug not enabled
if [[ $DEBUG == "false" ]]; then
  echo
  echo -n "start: "
  emitProgressDots &
  export PROCESSPID=$!
  trap killDots EXIT # kill progress dots if script exits
fi

debugOutput "MAIN: sourcing config file..."

source ${CONFFILE}
shift $((OPTIND -1))

debugOutput "MAIN: checking auth status"

checkAwsTokenValidity || {
  echo "ERROR: AWS CLI not authenticated"
  read -p "Authenticate again & Press enter to continue or \"ctrl-c\" to exit..."
}

createWorkingDirs
setupPgp

if [[ $CreateKeysOnly = "true" ]]; then
  if [[ $PGPOnly = "true" ]]; then

    debugOutput "MAIN: creating pgp keypair..."

    createPgpKeyPair

    debugOutput "MAIN: reset pgp"

    resetPgp
  elif [[ $SFTPOnly = "true" ]]; then

    debugOutput "MAIN: generating stfp keys..."

    createSftpKeyPair
  else
    debugOutput "MAIN: creating pgp keypair..."

    createPgpKeyPair

    debugOutput "MAIN: reset pgp"

    resetPgp

    debugOutput "MAIN: generating stfp keys..."

    createSftpKeyPair
  fi
elif [[ $TransmitOnly = "true" ]]; then
  collectTransmitFiles
  transmitSignedFileToChase
elif [[ $ActivatePGPOnly = "true" ]]; then

  debugOutput "MAIN: activating pgp keys..."

  collectActivationFile
  transmitSignedFileToChase
elif [[ $Finalize = "true" ]]; then

  debugOutput "MAIN: finalizing keys..."

  if [[ $PGPOnly = "true" ]]; then

    debugOutput "MAIN: finalizing pgp keys..."

    promoteCandidateToAWSCURRENT "${PGP_SECRET_KEY_SMPATH}"
    promoteCandidateToAWSCURRENT "${PGP_PUBLIC_KEY_SMPATH}"
  elif [[ $SFTPOnly = "true" ]]; then

    debugOutput "MAIN: finalizing sftp keys..."

    promoteCandidateToAWSCURRENT "${SFTP_SECRET_KEY_SMPATH}"
    promoteCandidateToAWSCURRENT "${SFTP_PUBLIC_KEY_SMPATH}"
  else
  
    echo -e "\nERROR: Finalize option requires -p or -s to specify which keys to finalize"
    echo -e "Exiting...\n" 

    Usage 1
  fi
else

  debugOutput "MAIN: Running key creation and transmission..."
  debugOutput "MAIN: NOTE: This will create and transmit both PGP and SFTP keys. Activation will not be performed."

  if [[ $PGPOnly = "true" ]]; then

    debugOutput "PGP only option selected..."
    debugOutput "creating pgp keypair and exporting keys..."

    createPgpKeyPair

    debugOutput "reset pgp"

    resetPgp
    collectTransmitFiles
    transmitSignedFileToChase

  elif [[ $SFTPOnly = "true" ]]; then
    
    debugOutput "SFTP only option selected..."
    debugOutput "generating stfp keys..."

    createSftpKeyPair
    collectTransmitFiles
    transmitSignedFileToChase

  else

    debugOutput "Creating and transmitting PGP and SFTP keys..."
    debugOutput "creating pgp keypair and exporting keys..."

    createPgpKeyPair

    debugOutput "reset pgp"

    resetPgp

    debugOutput "generating stfp keys..."

    createSftpKeyPair
    collectTransmitFiles
    transmitSignedFileToChase

  fi
fi

debugOutput "MAIN: cleaning up gpg agent..."

cleanPgpDir
cleanupWorkingDirs

# stop progress dots if debug not enabled
if [[ $DEBUG == "false" ]]; then
  killDots
  echo -n " :finish"
  echo
fi

echo
echo "MAIN: completed script execution"
echo