function createPgpKeyPair() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $SFTPOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: SFTP only, skipping PGP keypair creation"

        return
    fi
    if [[ $TransmitOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Transmit only, skipping PGP keypair creation"

        return
    fi
    if [[ $ActivateOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Activate only, skipping PGP keypair creation"

        return
    fi
    cd ${PGP_DIR} || errorOut "${FUNCNAME[0]}: failed to cd into ${PGP_DIR}"
    
    debugOutput "${FUNCNAME[0]}: creating the key pair"

    if [[ -z "${environment}" ]]; then
        errorOut "${FUNCNAME[0]}: environment variable not set, exiting..."
    else

        debugOutput "${FUNCNAME[0]}: environment variable set to ${environment}"

    fi
    # ${PGP_CONFIG_FILE} will have a line "Name-Comment: ${environment}-${timestamp}-chase-signing"
    # which needs explicit replacement before command is run to create the key pair
    # macos sed requires an empty string after -i flag, as an empty suffix for the backup (BSD)
    # linux will error if that same empty string is presented...

    debugOutput "${FUNCNAME[0]}: editing the config file to set the key identifier..."

    sed "s/^Name-Comment:.*$/Name-Comment: ${environment}-${timestamp}-chase-signing-pgp/g" "${SCRIPT_DIR}/conf/${PGP_CONFIG_FILE}" > "${PGP_DIR}/${PGP_CONFIG_FILE}"

    debugOutput "${FUNCNAME[0]}: creating the key pair..."

    # create the key pair
    gpg --batch --quiet --no-verbose --generate-key ${PGP_DIR}/${PGP_CONFIG_FILE} >/dev/null 2>&1 # this sets "devops@toasttab.com" as the key identifier for export commands later
    # verify (list keys)

    debugOutput "${FUNCNAME[0]}: keys created..."

    debugOutput "${FUNCNAME[0]}: collecting fingerprint from new pgp key..."
    
    # shellcheck disable=SC2002
    email=$(cat "${PGP_DIR}/${PGP_CONFIG_FILE}" | grep Name-Email: | awk -F: '{ print $2 }' | xargs)
    
    debugOutput "${FUNCNAME[0]}: email: ${email}"

    export FP=$(gpg --list-keys "${email}" | head -n2 | tail -n1 | tr -d '[:blank:]')
    
    debugOutput "${FUNCNAME[0]}: fingerprint: ${FP}"

    local chaseSerNum=$(echo "${FP}" | cut -c $((${#FP}-7))-${#FP}) # last 8 characters
    export activate_file=$(sed "s/0xSERIALNUMBER/0x${chaseSerNum}/g" "${SCRIPT_DIR}/conf/${CHASE_PGP_ACTIVATE_FILE_TEMPLATE}")
    exportPgpKeys
  
    debugOutput "${FUNCNAME[0]}: delete oldest secret label for pgp secret key..."

    deleteOldestSecretLabel "${PGP_SECRET_KEY_SMPATH}"

    debugOutput "${FUNCNAME[0]}: pushing up private pgp key..."

    pushKeyIntoSecretsmanager "${PGP_SECRET_KEY_SMPATH}" "${exported_priv_key}" "${YEAR}" "${TIMESTAMP}" "${FP}"

    debugOutput "${FUNCNAME[0]}: delete oldest secret label for pgp secret key..."

    deleteOldestSecretLabel "${PGP_PUBLIC_KEY_SMPATH}"

    debugOutput "${FUNCNAME[0]}: pushing up public pgp key..."

    pushKeyIntoSecretsmanager "${PGP_PUBLIC_KEY_SMPATH}" "${exported_pub_key}" "${YEAR}" "${TIMESTAMP}" "${FP}"

    debugOutput "${FUNCNAME[0]}: pushing up activation file..."

    deleteOldestSecretLabel "${CHASE_PGP_ACTIVATE_FILE_SMPATH}"
    pushKeyIntoSecretsmanager "${CHASE_PGP_ACTIVATE_FILE_SMPATH}" "${activate_file}" "${YEAR}" "${TIMESTAMP}" "${FP}"
    cleanPgpDir
}

function exportPgpKeys() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $SFTPOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: SFTP only, skipping PGP key export"

        return
    fi
    if [[ $TransmitOnly == "true" ]]; then  

        debugOutput "${FUNCNAME[0]}: Transmit only, skipping PGP key export"

        return
    fi
    if [[ $ActivateOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Activate only, skipping PGP key export"

        return
    fi
    # public key
    
    debugOutput "${FUNCNAME[0]}: exporting the public key"

    export exported_pub_key=$(gpg --armor --export devops@toasttab.com)
    # write public key to a file to be signed...
    gpg --quiet --no-verbose --batch --output "${PGP_DIR}/${PGP_PUBLIC_KEY}" --armor --export devops@toasttab.com >/dev/null 2>&1 
    
    # private key

    debugOutput "${FUNCNAME[0]}: exporting the private key"

    export exported_priv_key=$(gpg --armor --export-secret-key devops@toasttab.com)
}

function pushKeyIntoSecretsmanager() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $TransmitOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Transmit only, skipping secretsmanager push"

        return
    fi
    if [[ $ActivateOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Activate only, skipping secretsmanager push"

        return
    fi
    # Check if the correct number of arguments are provided
    if [ "$#" -lt 5 ]; then
        errorOut "${FUNCNAME[0]}: Usage: ${FUNCNAME[0]} <secret-location> <secret-value> <year> <timestamp> <fingerprint"
    fi
    # Assign the first argument to the secret location, second to the secret content (key)
    local SECRET_LOCATION=$1
    local SECRET=$2
    local YEAR=$3
    local TIMESTAMP=$4
    local FP=$5
    # Upload the secret with the timestamp tag
    local PUT_RESULT=$(aws secretsmanager put-secret-value --secret-id "$SECRET_LOCATION" --secret-string "$SECRET" --version-stages "$TIMESTAMP" "$FP")
    # Retrieve the version ID of the secret with the year tag
    local PREVIOUS_CANDIDATE_VERSION_ID=$(aws secretsmanager list-secret-version-ids --secret-id "$SECRET_LOCATION" \
        --output json | jq -r ".Versions[] | select(.VersionStages | index(\"$YEAR\")) | .VersionId")

    debugOutput "${FUNCNAME[0]}: PREVIOUS_CANDIDATE_VERSION_ID: $PREVIOUS_CANDIDATE_VERSION_ID"

    # Retrieve the version ID of the newly uploaded secret
    local NEW_VERSION_ID=$(aws secretsmanager list-secret-version-ids --secret-id "$SECRET_LOCATION" \
        --output json | jq -r ".Versions[] | select(.VersionStages | index(\"$TIMESTAMP\")) | .VersionId")

    debugOutput "${FUNCNAME[0]}: NEW_VERSION_ID: $NEW_VERSION_ID"

    # validate secret in memory matches secret in version id
    key_in_secretsmanager=$(aws secretsmanager get-secret-value --secret-id "$SECRET_LOCATION" --version-id "$NEW_VERSION_ID" --query SecretString | jq -r '.')
    if [ "$key_in_secretsmanager" != "$SECRET" ]; then
        errorOut "${FUNCNAME[0]}: Secret in memory does not match secret in secretsmanager"
    else

        debugOutput "${FUNCNAME[0]}: Secret in memory matches secret in secretsmanager"

    fi
    # Update the version stage to move the year tag to the new version

    if [ -n "$PREVIOUS_CANDIDATE_VERSION_ID" ]; then
       year_staging_output=$(aws secretsmanager update-secret-version-stage --secret-id "$SECRET_LOCATION" --version-stage "$YEAR" \
            --move-to-version-id "$NEW_VERSION_ID" --remove-from-version-id "$PREVIOUS_CANDIDATE_VERSION_ID")
    else
        year_staging_output=$(aws secretsmanager update-secret-version-stage --secret-id "$SECRET_LOCATION" --version-stage "$YEAR" \
            --move-to-version-id "$NEW_VERSION_ID")
    fi

    debugOutput "${FUNCNAME[0]}: year_staging_output: $year_staging_output"
    
}

function promoteCandidateToAWSCURRENT() {
    echo -en " \n     ${FUNCNAME[0]} "

    debugOutput "${FUNCNAME[0]}: Promoting candidate to AWSCURRENT..."
    debugOutput "${FUNCNAME[0]}: secret_id: $1"

    if [[ $TransmitOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Transmit only, skipping secretsmanager promotion"

        return
    fi
    if [[ $ActivateOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Activate only, skipping secretsmanager promotion"

        return
    fi
    # derive AWSCURRENT_VERSION_ID
    local secret_id="${1}"
    local aws_current_version_id=$(aws secretsmanager list-secret-version-ids --secret-id "${secret_id}" \
        --output json | jq -r ".Versions[] | select(.VersionStages | index(\"AWSCURRENT\")) | .VersionId")

    debugOutput "${FUNCNAME[0]}: Moving AWSCURRENT to the version with the current year tag..."

    local candidate_version_id=$(aws secretsmanager list-secret-version-ids --secret-id "${secret_id}" \
        --output json | jq -r ".Versions[] | select(.VersionStages | index(\"${YEAR}\")) | .VersionId")
    if [[ "$aws_current_version_id" == "$candidate_version_id" ]]; then

        debugOutput "${FUNCNAME[0]}: The candidate version is already the current version."

        return
    fi
    aws secretsmanager update-secret-version-stage \
        --secret-id "${secret_id}" \
        --version-stage AWSCURRENT \
        --move-to-version-id "${candidate_version_id}" \
        --remove-from-version-id "${aws_current_version_id}"
    # AWSPREVIOUS moves automagically to the secret version id from which you remove AWSCURRENT
}

function deleteOldestSecretLabel() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $TransmitOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Transmit only, skipping secretsmanager label deletion"

        return
    fi
   local secret_id=$1
    # Fetch all versions and their staging labels for the secret

    debugOutput "${FUNCNAME[0]}: Fetching versions for secret: $secret_id"

    local versions
    versions=$(aws secretsmanager list-secret-version-ids --secret-id "$secret_id" --query 'Versions[*].{VersionId:VersionId,StagingLabels:VersionStages}' --output json)
    
    debugOutput "${FUNCNAME[0]}: Versions fetched: $versions"

    # Create a map of version_id -> staging labels
    declare -A version_map
    local version_id staging_labels label
    for version in $(echo "$versions" | jq -r '.[] | @base64'); do
        _jq() {
            echo "$version" | base64 --decode | jq -r "${1}"
        }
        version_id=$(_jq '.VersionId')
        staging_labels=$(_jq '.StagingLabels[]')

        for label in $staging_labels; do
            version_map["$version_id"]+="$label "
        done
    done
    # Calculate total number of labels
    total_labels() {
        local count=0
        for version_id in "${!version_map[@]}"; do
            labels=${version_map[$version_id]}
            count=$((count + $(echo "$labels" | wc -w)))
        done
        echo "$count"
    }
    # Initial total labels count
    total_label_count=$(total_labels)

    debugOutput "${FUNCNAME[0]}: Initial total labels count: $total_label_count"

    # If total labels count is less than or equal to "${NUMLABELS}", do nothing
    if [ "$total_label_count" -le "${NUMLABELS}" ]; then

        debugOutput "${FUNCNAME[0]}: Total labels count is less than or equal to "${NUMLABELS}". No cleanup needed."
        
        return
    fi
    # Fetch creation dates and create the sorted version list
    local creation_dates
    creation_dates=$(aws secretsmanager list-secret-version-ids --secret-id "$secret_id" --query 'Versions[*].{VersionId:VersionId,CreatedDate:CreatedDate}' --output json)
    
    # Create a map of version_id -> creation date
    declare -A creation_date_map
    for version in $(echo "$creation_dates" | jq -r '.[] | @base64'); do
        _jq() {
            echo "$version" | base64 --decode | jq -r "${1}"
        }
        version_id=$(_jq '.VersionId')
        created_date=$(_jq '.CreatedDate')
        creation_date_map["$version_id"]=$created_date
    done
    # Sort versions by creation date
    sorted_versions=$(for version_id in "${!creation_date_map[@]}"; do
        echo "$version_id,${creation_date_map[$version_id]}"
    done | sort -t',' -k2)
    # Print the sorted versions for debugging

    debugOutput "${FUNCNAME[0]}: Sorted versions: $sorted_versions"

    # Filter and delete versions based on criteria
    original_IFS=$IFS
    for version in $sorted_versions; do
        IFS=','
        read -r version_id created_date <<< "$version"
        IFS=$original_IFS
        labels=${version_map[$version_id]}
        keep=false
        current_year=$(date +"%Y")
        previous_year=$((current_year - 1))

        for label in $labels; do
            if [[ "$label" == "AWSCURRENT" || "$label" == "AWSPREVIOUS" || "$label" == "$current_year" || "$label" == "$previous_year" ]]; then
                keep=true
                break
            fi
        done
        if [ "$keep" = false ]; then
            # Delete the version if it doesn't meet the criteria

            debugOutput "${FUNCNAME[0]}: Deleting labels for version_id: $version_id"

            for label in $labels; do

                debugOutput "${FUNCNAME[0]}: Removing label: $label"

                aws secretsmanager update-secret-version-stage --secret-id "$secret_id" --version-stage "$label" --remove-from-version-id "$version_id" > /dev/null
            done
            unset version_map[$version_id]

            # Recalculate total labels
            total_label_count=$(total_labels)

            debugOutput "${FUNCNAME[0]}: Total labels count after deletion: $total_label_count"

            if [ "$total_label_count" -lt "${NUMLABELS}" ]; then

                debugOutput "${FUNCNAME[0]}: Total labels count is below "${NUMLABELS}". Stopping cleanup."

                break
            fi
        fi
    done

    debugOutput "${FUNCNAME[0]}: Cleanup complete."
    
}

function updateSecretLabels() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $TransmitOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Transmit only, skipping secretsmanager label update"

        return
    fi
    local secret_id="$1"
    # List all versions of the secret
    versions=$(aws secretsmanager list-secret-version-ids --secret-id "$secret_id" --query 'Versions[]' --output json)
    # Initialize variables to hold version IDs
    local current_year=${YEAR}
    local candidate_version_id=""
    local current_active_version_id=""
    local previous_active_version_id=""
    # Iterate over each version to find the required labels
    for version in $(echo "$versions" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${version} | base64 --decode | jq -r ${1}
        }

        version_id=$(_jq '.VersionId')
        staging_labels=$(_jq '.VersionStages[]?')

        # Check for current year tag
        if echo "$staging_labels" | grep -q "$current_year"; then
            candidate_version_id="$version_id"
        fi

        # Check for AWSCURRENT
        if echo "$staging_labels" | grep -q "AWSCURRENT"; then
            current_active_version_id="$version_id"
        fi

        # Check for AWSPREVIOUS
        if echo "$staging_labels" | grep -q "AWSPREVIOUS"; then
            previous_active_version_id="$version_id"
        fi
    done
    # Validate that we found all necessary version IDs
    if [ -z "$candidate_version_id" ]; then

        debugOutput "${FUNCNAME[0]}: WARNING: Could not find a version with the current year tag ($current_year)."

        return 1
    fi
    if [ -z "$current_active_version_id" ]; then

        debugOutput "${FUNCNAME[0]}: WARNING: Could not find a version with the AWSCURRENT tag."

        return 1
    fi
    if [ -z "$previous_active_version_id" ]; then

        debugOutput "${FUNCNAME[0]}: WARNING: Could not find a version with the AWSPREVIOUS tag. This is correct if this is the first or second version of the secret (no AWSPREVIOUS)"
       
        return 1
    fi

    debugOutput "${FUNCNAME[0]}: Version IDs"
    debugOutput "${FUNCNAME[0]}: Candidate version ID: $candidate_version_id"
    debugOutput "${FUNCNAME[0]}: Current active version ID: $current_active_version_id"
    debugOutput "${FUNCNAME[0]}: Previous active version ID: $previous_active_version_id"
    debugOutput "${FUNCNAME[0]}: Update complete."
}

function createSftpKeyPair() {
  echo -en " \n     ${FUNCNAME[0]} "
  if [[ $PGPOnly == "true" ]]; then
    debugOutput "${FUNCNAME[0]}: PGP only, skipping SFTP keypair creation"
    return
  fi
  if [[ $TransmitOnly == "true" ]]; then
    debugOutput "${FUNCNAME[0]}: Transmit only, skipping SFTP keypair creation"
    return
  fi
  if [[ $ActivateOnly == "true" ]]; then
    debugOutput "${FUNCNAME[0]}: Activate only, skipping SFTP keypair creation"
    return
  fi
  # ssh key generate command
  local ssh_cmd="ssh-keygen -m pem -b 2048 -f ${SFTP_DIR}/${SFTP_SECRET_KEY} -t rsa -N \"\" -C \"${EMAIL}-${YEAR}-${environment}\""
  if [[ ! -d "${SFTP_DIR}" ]]; then
       createWorkingDirs "${environment}"
  fi

  debugOutput "${FUNCNAME[0]}: Generating ${SFTP_SECRET_KEY} and ${SFTP_PUBLIC_KEY} ssh keypair files"
  debugOutput "${FUNCNAME[0]}: Comment will have ${EMAIL} plus ${YEAR} plus ${environment}"
  debugOutput "${FUNCNAME[0]}: Running command: "
  debugOutput "${FUNCNAME[0]}: ${ssh_cmd}"

  sftp_keygen_output=$(eval "${ssh_cmd}")
  
  debugOutput "ssh keygen output:  $sftp_keygen_output"
  debugOutput "${FUNCNAME[0]}: SFTP key create is complete"

  # put private and public key into memory and remove private key, presevre public for signing
  # use sha1sum to create a checksum of the public key. Use this as fingerprint for secretsmanager label
  export sftp_private_key=$(cat ${SFTP_DIR}/${SFTP_SECRET_KEY}) && rm -f ${SFTP_DIR}/${SFTP_SECRET_KEY}
  export sftp_public_key=$(cat ${SFTP_DIR}/${SFTP_PUBLIC_KEY}) 
  export sftp_keypair_checksum=$(echo "${sftp_public_key}" | shasum -a 1 | awk '{ print $1 }')
  deleteOldestSecretLabel "${SFTP_SECRET_KEY_SMPATH}"
  pushKeyIntoSecretsmanager "${SFTP_SECRET_KEY_SMPATH}" "${sftp_private_key}" "${YEAR}" "${TIMESTAMP}" "${sftp_keypair_checksum}"
  deleteOldestSecretLabel "${SFTP_PUBLIC_KEY_SMPATH}"
  pushKeyIntoSecretsmanager "${SFTP_PUBLIC_KEY_SMPATH}" "${sftp_public_key}" "${YEAR}" "${TIMESTAMP}" "${sftp_keypair_checksum}"
}

function collectActivePgpKey() {
    echo -en " \n     ${FUNCNAME[0]} "
    # grab the current pgp AWSCURRENT private key to import into gpg
    # get the current active secret

    debugOutput "${FUNCNAME[0]}: collecting the active PGP key..."

    local pgp_secret_key_smpath="${1}"
    # get the current pgp active secret key to sign with
    local pgp_secret_key=$(aws secretsmanager get-secret-value --secret-id \
    "${pgp_secret_key_smpath}" --version-stage AWSCURRENT --query SecretString --output text)
    # import key into gpg from variable

    debugOutput "${FUNCNAME[0]}: importing key..."

    echo "${pgp_secret_key}" | gpg --batch --quiet --no-tty --no-verbose --import >/dev/null 2>&1 || errorOut "${FUNCNAME[0]}: failed to import PGP secret key from variable"

    debugOutput "${FUNCNAME[0]}: current pgp key imported"
    debugOutput "${FUNCNAME[0]}: setting trust..."
    
    # shellcheck disable=SC2002
    local email=$(cat ${GNUPGHOME}/${PGP_CONFIG_FILE} | grep Name-Email: | awk -F: '{ print $2 }' | xargs)

    debugOutput "${FUNCNAME[0]}: email: ${email}" 

    local FP=$(gpg --list-keys "${email}" | head -n2 | tail -n1 | tr -d '[:blank:]')

    debugOutput "${FUNCNAME[0]}: FP: ${FP}"
    debugOutput "${FUNCNAME[0]}: setting trust for ${email} with fingerprint ${FP}"

    echo -e "5\ny\n" | gpg --batch --quiet --no-tty --no-verbose --command-fd 0 --edit-key "$FP" trust >/dev/null 2>&1 || errorOut "${FUNCNAME[0]}: failed to set trust for PGP key"

    debugOutput "${FUNCNAME[0]}: check trust level..."

    output=$(gpg --batch --quiet --no-tty --no-verbose --list-keys --with-colons "${FP}")
    trust_level=$(echo "$output" | awk -F: '/^pub/ {print $9}')
    case $trust_level in
        "-") trust_desc="No ownertrust assigned / unknown";;
        "e") trust_desc="Trust level for this key cannot be determined";;
        "q") trust_desc="This key is non-revocable";;
        "n") trust_desc="Never trust this key";;
        "m") trust_desc="Marginal trust";;
        "f") trust_desc="Full trust";;
        "u") trust_desc="Ultimate trust";;
        *) trust_desc="Unknown trust level";;
    esac
    debugOutput "${FUNCNAME[0]}: Trust level: $trust_level ($trust_desc)"
}

function pgpSignFile() {
    echo -en " \n     ${FUNCNAME[0]} "

    debugOutput "${FUNCNAME[0]}: Collecting active PGP key to sign file..."

    collectActivePgpKey "${PGP_SECRET_KEY_SMPATH}"
    # Sign the file with the active PGP key, including the content and the signature in the same file

    debugOutput "${FUNCNAME[0]}: Signing ${1} with the active PGP key, including the content and the signature in the same file..."

    # Assign args
    local file_to_sign="${1}"
    local signed_file="${2}"

    debugOutput "${FUNCNAME[0]}: File to sign: ${file_to_sign}"
    debugOutput "${FUNCNAME[0]}: Signed file: ${signed_file}"
    
    gpg --armor --sign --quiet --no-tty --no-verbose --output "${signed_file}" "${file_to_sign}" >/dev/null 2>&1 || errorOut "${FUNCNAME[0]}: Failed to sign file ${file_to_sign}"

    debugOutput "${FUNCNAME[0]}: File ${file_to_sign} signed and saved as ${signed_file}, including the content and the signature."

}

function collectActiveSftpAndHostKeys() {
    echo -en " \n     ${FUNCNAME[0]} "
    # get the current active secret

    debugOutput "${FUNCNAME[0]}: collecting the active SFTP key..."

    # get the current sftp active secret key to sign with
    local sftp_secret_key=$(aws secretsmanager get-secret-value --secret-id \
    "${SFTP_SECRET_KEY_SMPATH}" --version-stage AWSCURRENT --query SecretString --output text)
    # write sftp private key (active) to a file

    debugOutput "${FUNCNAME[0]}: importing key..."

    echo "${sftp_secret_key}" > "${CHASE_SFTP_PRIVATE_KEY}" || errorOut "${FUNCNAME[0]}: failed to create SFTP secret key"
    chmod 600 "${CHASE_SFTP_PRIVATE_KEY}" || errorOut "${FUNCNAME[0]}: failed to chmod 600 ${CHASE_SFTP_PRIVATE_KEY}"

    debugOutput "${FUNCNAME[0]}: current active sftp key file collected"

    # get the current Chase host key...

    debugOutput "${FUNCNAME[0]}: collecting the active SFTP HOST key..."

    # get the current sftp host key to verify the sftp server
    local sftp_host_key=$(aws secretsmanager get-secret-value --secret-id \
    "${CHASE_SFTP_HOST_KEY_SMPATH}" --version-stage AWSCURRENT --query SecretString --output text)
    # write sftp host key to a file

    debugOutput "${FUNCNAME[0]}: importing key..."

    echo "${sftp_host_key}" > "${CHASE_SFTP_HOST_KEY}" || errorOut "${FUNCNAME[0]}: failed to create SFTP host key"
     
    debugOutput "${FUNCNAME[0]}: current active sftp host key file collected"
}

function transmitSignedFileToChase() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $CreateKeysOnly == "true" ]]; then
        debugOutput "${FUNCNAME[0]}: Create keys only, skipping transmission"
        return
    fi
    case ${environment} in 
        "playground")
          export SFTP_HOST="${CHASE_TEST_SFTP}"
          ;;
        "uat")
          export SFTP_HOST="${CHASE_UAT_SFTP}"
          ;;
        "preproduction")
          export SFTP_HOST="${CHASE_UAT_SFTP}"
          ;;
        "prod")
          export SFTP_HOST="${CHASE_PROD_SFTP}"
          ;;
        *)
          errorOut "${FUNCNAME[0]}: Environment not recognized, SFTP_HOST not set"
          ;;
    esac

    debugOutput "${FUNCNAME[0]}: SFTP_HOST: ${SFTP_HOST}"

    # scp command
    collectActiveSftpAndHostKeys || errorOut "${FUNCNAME[0]}: failed to collect active SFTP and host keys"
    local scp_cmd="scp -r -i ${CHASE_SFTP_PRIVATE_KEY} -o UserKnownHostsFile=${CHASE_SFTP_HOST_KEY} ${SFTP_OPTIONS}"

    debugOutput "${FUNCNAME[0]}: uploading files in ${TRANSPORT_DIR} to Chase secure SFTP server via ${scp_cmd}..."
    local file_count=$(find "${TRANSPORT_DIR}" -type f | wc -l)
    if [[ $file_count -eq 0 ]]; then
        errorOut "${FUNCNAME[0]}: No files found in ${TRANSPORT_DIR} to transmit"
    fi
    for file in $(ls -1 "${TRANSPORT_DIR}"); do

        debugOutput "${FUNCNAME[0]}: uploading ${file}..."

        scp_output=$(${scp_cmd} "${TRANSPORT_DIR}/${file}" "${SFTP_HOST}:/Inbound/Encrypted/") \
        || errorOut "${FUNCNAME[0]}: Upload of ${file} failed"

        debugOutput "${FUNCNAME[0]}: scp output (file names transmitted):  $scp_output"

    done

    debugOutput "${FUNCNAME[0]}: upload complete"

    cleanupAfterTransmit
}

function cleanupAfterTransmit() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $CreateKeysOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Create keys only, skipping cleanup"

        return
    fi

    debugOutput "${FUNCNAME[0]}: cleaning ${TRANSPORT_DIR} directory..."

    rm -f "${TRANSPORT_DIR}/*"

    debugOutput "${FUNCNAME[0]}: clean up complete"

}

function collectActivationFile() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $SFTPOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: SFTP only, skipping activation file collection"

        return
    fi
    if [[ $CreateKeysOnly == "true" ]]; then

        debugOutput "${FUNCNAME[0]}: Create keys only, skipping activation file collection"

        return
    fi

    debugOutput "${FUNCNAME[0]}: Cleaning up Activation Directory: ${ACTIVATE_DIR}"

    rm -f "${ACTIVATE_DIR}/*"
    # promote the candidate to AWSCURRENT
    promoteCandidateToAWSCURRENT "${CHASE_PGP_ACTIVATE_FILE_SMPATH}" || errorOut "${FUNCNAME[0]}: failed to promote candidate to AWSCURRENT"
    local activate_file=$(aws secretsmanager get-secret-value --secret-id \
    "${SFTP_SECRET_KEY_SMPATH}" --version-stage AWSCURRENT --query SecretString --output text)
    echo $activate_file > "${CHASE_PGP_ACTIVATE_FILE}" || errorOut "${FUNCNAME[0]}: failed to create activation file"
    pgpSignFile "${ACTIVATE_DIR}/${ACTIVATE_FILE}" "${TRANSPORT_DIR}/${ACTIVATE_FILE}" || errorOut "${FUNCNAME[0]}: failed to sign activation file"

}

function revertActiveSecret() {
    echo -en " \n     ${FUNCNAME[0]} "
    local secret_id="$1"

    # List all versions of the secret
    versions=$(aws secretsmanager list-secret-version-ids --secret-id "$secret_id" --query 'Versions[]' --output json)

    # Initialize variables to hold version IDs
    current_active_version_id=""
    previous_active_version_id=""

    # Iterate over each version to find the required labels
    for version in $(echo "$versions" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${version} | base64 --decode | jq -r ${1}
        }

        version_id=$(_jq '.VersionId')
        staging_labels=$(_jq '.VersionStages[]?')

        # Check for AWSCURRENT
        if echo "$staging_labels" | grep -q "AWSCURRENT"; then
            current_active_version_id="$version_id"
        fi

        # Check for AWSPREVIOUS
        if echo "$staging_labels" | grep -q "AWSPREVIOUS"; then
            previous_active_version_id="$version_id"
        fi
    done

    # Validate that we found the necessary version IDs
    if [ -z "$current_active_version_id" ]; then
        errorOut "${FUNCNAME[0]}: Could not find a version with the AWSCURRENT tag."
    fi

    if [ -z "$previous_active_version_id" ]; then
        errorOut "${FUNCNAME[0]}: Could not find a version with the AWSPREVIOUS tag"
    fi

    debugOutput "${FUNCNAME[0]}: Reverting AWSCURRENT to the version with AWSPREVIOUS tag..."

    aws secretsmanager update-secret-version-stage \
        --secret-id "$secret_id" \
        --version-stage AWSCURRENT \
        --move-to-version-id "$previous_active_version_id" \
        --remove-from-version-id "$current_active_version_id"

    
    debugOutput "${FUNCNAME[0]}: Revert complete. AWSCURRENT is now set to version $previous_active_version_id."

}

function collectTransmitFiles() {
    echo -en " \n     ${FUNCNAME[0]} "
    if [[ $CreateKeysOnly == "true" ]]; then
        debugOutput "${FUNCNAME[0]}: Create keys only, skipping file collection"
        return
    fi
    if [[ $SFTPOnly == "true" ]]; then
        debugOutput "${FUNCNAME[0]}: collecting SFTP public key candidate for transmission..."
        local sftp_public_key=$(aws secretsmanager get-secret-value --secret-id \
        "${SFTP_PUBLIC_KEY_SMPATH}" --version-stage ${YEAR} --query SecretString --output text)
        echo $sftp_public_key > "${SFTP_DIR}/${SFTP_PUBLIC_KEY}" || errorOut "${FUNCNAME[0]}: failed to create SFTP public key"
        pgpSignFile "${SFTP_DIR}/${SFTP_PUBLIC_KEY}" "${TRANSPORT_DIR}/${SFTP_SIGNED_PUBKEY_FILE_NAME}" || errorOut "${FUNCNAME[0]}: failed to sign SFTP public key"
        return
    elif [[ $PGPOnly == "true" ]]; then
        debugOutput "${FUNCNAME[0]}: collecting PGP public key candidate for transmission..."
        local pgp_public_key=$(aws secretsmanager get-secret-value --secret-id \
        "${PGP_PUBLIC_KEY_SMPATH}" --version-stage ${YEAR} --query SecretString --output text)
        echo $pgp_public_key > "${PGP_DIR}/${PGP_PUBLIC_KEY}" || errorOut "${FUNCNAME[0]}: failed to create PGP public key"
        pgpSignFile "${PGP_DIR}/${PGP_PUBLIC_KEY}" "${TRANSPORT_DIR}/${PGP_SIGNED_PUBKEY_FILE_NAME}" || errorOut "${FUNCNAME[0]}: failed to sign PGP public key"
        return
    else
        debugOutput "${FUNCNAME[0]}: collecting PGP and SFTP public key candidates for transmission..."
        local pgp_public_key=$(aws secretsmanager get-secret-value --secret-id \
        "${PGP_PUBLIC_KEY_SMPATH}" --version-stage ${YEAR} --query SecretString --output text)
        echo $pgp_public_key > "${PGP_DIR}/${PGP_PUBLIC_KEY}" || errorOut "${FUNCNAME[0]}: failed to create PGP public key"
        pgpSignFile "${PGP_DIR}/${PGP_PUBLIC_KEY}" "${TRANSPORT_DIR}/${PGP_SIGNED_PUBKEY_FILE_NAME}" || errorOut "${FUNCNAME[0]}: failed to sign PGP public key"
        local sftp_public_key=$(aws secretsmanager get-secret-value --secret-id \
        "${SFTP_PUBLIC_KEY_SMPATH}" --version-stage ${YEAR} --query SecretString --output text)
        echo $sftp_public_key > "${SFTP_DIR}/${SFTP_PUBLIC_KEY}" || errorOut "${FUNCNAME[0]}: failed to create SFTP public key"
        pgpSignFile "${SFTP_DIR}/${SFTP_PUBLIC_KEY}" "${TRANSPORT_DIR}/${SFTP_SIGNED_PUBKEY_FILE_NAME}" || errorOut "${FUNCNAME[0]}: failed to sign SFTP public key"
        return
    fi
    local filesToTransmit=$(find "${TRANSMIT_DIR}" -type f)
    if [[ -z "${filesToTransmit}" ]]; then
        errorOut "${FUNCNAME[0]}: No files found in ${TRANSMIT_DIR} to transmit..."
    fi
    debugOutput "${FUNCNAME[0]}: files to transmit: ${filesToTransmit}"
    cleanupAfterTransmit
}
