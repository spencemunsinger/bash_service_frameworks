# errorOut - prints an error message and exits with a non-zero exit code
# used in create_keys_functions.sh, setup_functions.sh
function errorOut() {
     echo
     echo "ERROR: $@"
     echo "Exiting..."
     echo
     exit 1
}

function debugOutput() {
    if [[ $DEBUG == "true" ]]; then
        for line in "$@"; do
            echo
            echo "DEBUG: $line"
            echo
        done
    fi
}

function Usage() {
    local exit_code=$1
    echo
    echo "Usage: $0 [:ace:fpsthd]"
    echo
    echo "Options:"
    echo "  -a          Activate PGP keys at Chase end only.  This transmits the activation file to Chase."
    echo "  -c          Create PGP and/or SFTP keys only"
    echo "              Combine with -s for SFTP only."
    echo "              Combine with -p for PGP only."
    echo "              Default behavior is to create both."
    echo "  -e          Set the environment.  This argument must be submitted with one of the following values:"
    echo "              -e playground"
    echo "              -e uat"
    echo "              -e preproduction"
    echo "              -e prod"
    echo "  -f          Finalize a set of keys as ACTIVE, PGP OR SFTP (never both at once)."
    echo "              This will promote the keys to the active (AWSCURRENT) keys in secretsmanager."
    echo "              Must also specify -p (PGP) or -s (SFTP) to specify which keys to be promoted."
    echo "  -p          Create, promote or transmit PGP keys only"
    echo "  -s          Create, promote or transmit SFTP keys only"
    echo "  -t          Transmit public PGP and/or SFTP keys to Chase via scp"
    echo "              Compine with -s for SFTP only."
    echo "              Combine with -p for PGP only."
    echo "              Default behavior is to transmit both."    
    echo "  -h          Display this help message"
    echo "  -d          Enable debug mode (verbose output)"
    echo
    if [[ $exit_code -eq 1 ]]; then
        exit 1
    else
        exit 0
    fi
}

function emitProgressDots() {
  while true; do
    echo -n "."
    sleep 1
  done
}

function killDots() {
  if [[ -n $PROCESSPID ]] && kill -0 $PROCESSPID 2>/dev/null; then
    kill $PROCESSPID >/dev/null 2>&1
  fi
}
