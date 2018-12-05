# =============================================================================
# COMMON VARIABLES
# =============================================================================

# Package dependencies
PKG_DEPENDENCIES="php5-cli php5-mysql php5-json php5-gd php5-tidy php5-curl php-gettext"

# Execute a command as another user
# usage: exec_as USER COMMAND [ARG ...]
exec_as() {
  local USER=$1
  shift 1

  if [[ $USER = $(whoami) ]]; then
    eval $@
  else
    # use twice to be root and be allowed to use another user
    sudo -u "$USER" "$@"
  fi
}

# =============================================================================
# COMMON PILEA FUNCTIONS
# =============================================================================

# Execute a command through the Pilea console
# usage: exec_console AS_USER WORKDIR COMMAND [ARG ...]
exec_console() {
  local AS_USER=$1
  local WORKDIR=$2
  shift 2
  exec_as "$AS_USER" php "$WORKDIR/bin/console" --no-interaction --env=prod "$@"
}

WARNING () {	# Print on error output
  $@ >&2
}

QUIET () {	# redirect standard output to /dev/null
  $@ > /dev/null
}

CHECK_SIZE () {	# Check if enough disk space available on backup storage
  file_to_analyse=$1
  backup_size=$(du --summarize "$file_to_analyse" | cut -f1)
  free_space=$(df --output=avail "/home/yunohost.backup" | sed 1d)

  if [ $free_space -le $backup_size ]
  then
    WARNING echo "Not enough backup disk space for: $file_to_analyse."
    WARNING echo "Space available: $(HUMAN_SIZE $free_space)"
    ynh_die "Space needed: $(HUMAN_SIZE $backup_size)"
  fi
}

# Execute a composer command from a given directory
# usage: composer_exec workdir COMMAND [ARG ...]
exec_composer() {
  local workdir=$1
  shift 1

  COMPOSER_HOME="${workdir}/.composer" \
    php "${workdir}/composer.phar" $@ \
      -d "${workdir}" --quiet --no-interaction
}

# Install and initialize Composer in the given directory
# usage: init_composer destdir
init_composer() {
  local destdir=$1

  # install composer
  curl -sS https://getcomposer.org/installer \
    | COMPOSER_HOME="${destdir}/.composer" \
        php -- --quiet --install-dir="$destdir" \
    || ynh_die "Unable to install Composer"

  # install composer.json
  cp "${destdir}/composer.json-dist" "${destdir}/composer.json"

  # update dependencies to create composer.lock
  exec_composer "$destdir" install \
    || ynh_die "Unable to install Pilea Composer dependencies"
}


# ============= FUTURE YUNOHOST HELPER =============
# Delete a file checksum from the app settings
#
# $app should be defined when calling this helper
#
# usage: ynh_remove_file_checksum file
# | arg: file - The file for which the checksum will be deleted
ynh_delete_file_checksum () {
  local checksum_setting_name=checksum_${1//[\/ ]/_}	# Replace all '/' and ' ' by '_'
  ynh_app_setting_delete $app $checksum_setting_name
}
