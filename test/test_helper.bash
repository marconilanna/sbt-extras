export TEST_ROOT="$BATS_TMPDIR/sbt_test.$$" && mkdir -p "$TEST_ROOT"
export TMP="$TEST_ROOT"
export HOME="$TEST_ROOT"
export PATH="$BATS_TEST_DIRNAME/../bin:$TEST_ROOT/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"

unset JAVA_HOME
unset JVM_OPTS
unset SBT_OPTS

export sbt_latest_07="0.7.7"
export sbt_latest_10="0.10.1"
export sbt_latest_11="0.11.3"
export sbt_latest_12="0.12.4"
export sbt_latest_13="0.13.2"
export sbt_latest_dev="0.13.5-M4"
export sbt_release_version="$sbt_latest_13"

export latest_28="2.8.2"
export latest_29="2.9.3"
export latest_210="2.10.4"
export latest_211="2.11.0"

teardown() { [[ -d "$TEST_ROOT" ]] && rm -rf -- "$TEST_ROOT"; }

# Usage: f <string which should be in output> [args to sbt]
sbt_expecting () { sbt_anticipating expect "$@"; }
# Usage: f <string which must not be in output> [args to sbt]
sbt_rejecting () { sbt_anticipating reject "$@"; }

sbt_anticipating () {
  case "$1" in
    expect) grep_opts="-F" && shift ;;
    reject) grep_opts="-Fv" && shift ;;
         *) return 1
  esac

  local text="$1" && shift
  stub_java
  run sbt "$@"
  assert_success
  assert_grep "$text" "$grep_opts"
  unstub java
}

setup_version_project () {
  create_project_with_launcher "$@"
  if [[ $# -gt 0 ]]; then
    echo "sbt.version=$1" > "$sbt_project/project/build.properties"
  fi
}

create_project_with_launcher() {
  local version="${1:-$sbt_release_version}"
  create_project $version
  create_launcher $version
}

create_project() {
  export sbt_project="$TEST_ROOT/myproject"
  export sbt_tested_version="$1"
  mkdir -p "$sbt_project/project" && cd "$sbt_project"
}

create_launcher() {
  mkdir -p "$TEST_ROOT/.sbt/launchers/$1"
  touch "$TEST_ROOT/.sbt/launchers/$1/sbt-launch.jar"
}

stub() {
  local program="$1"
  local prefix="$(echo "$program" | tr a-z- A-Z_)"
  shift

  export "${prefix}_STUB_PLAN"="$TEST_ROOT/${program}-stub-plan"
  export "${prefix}_STUB_RUN"="$TEST_ROOT/${program}-stub-run"
  export "${prefix}_STUB_END"=

  mkdir -p "$TEST_ROOT/bin"
  ln -sf "${BATS_TEST_DIRNAME}/stubs/stub" "$TEST_ROOT/bin/${program}"

  touch "$TEST_ROOT/${program}-stub-plan"
  for arg in "$@"; do printf "%s\n" "$arg" >> "$TEST_ROOT/${program}-stub-plan"; done
}

unstub() {
  local program="$1"
  local prefix="$(echo "$program" | tr a-z- A-Z_)"
  local path="$TEST_ROOT/bin/${program}"

  export "${prefix}_STUB_END"=1

  local STATUS=0
  "$path" || STATUS="$?"

  rm -f "$path"
  rm -f "$TEST_ROOT/${program}-stub-plan" "$TEST_ROOT/${program}-stub-run"
  return "$STATUS"
}

assert_success() {
  [ $status -ne 0 ] && printf "command failed with exit status $status\noutput: $output\n" | flunk
  [[ $# -eq 0 ]] || assert_output "$1"
}

assert_failure() {
  [ $status -eq 0 ] && printf "expected failure" | flunk
  [[ $# -eq 0 ]] || assert_output "$1"
}

stdin_or_args () { if [[ $# -eq 0 ]]; then cat - ; else echo "$@"; fi; }
normalize_paths () {
  stdin_or_args "$@" | \
    sed "s:$TEST_ROOT:\$ROOT:g" | \
    sed "s:$HOME:\$ROOT:g"
}

assert()        { "$@" || flunk "failed: $@"; }
flunk()         { normalize_paths "$@" ; return 1; }
assert_equal()  { [ "$1" == "$2" ] || printf "expected: %s\nactual:   %s\n" "$1" "$2" | flunk; }
assert_output() { assert_equal "${1:-$(cat -)}" "$output"; }

assert_grep() {
  local expected="$1" && shift

  echo "$output" | grep "$@" -- "$expected" >/dev/null || {
    { echo "expected output to contain $expected"
      echo "actual: $output"
    } | flunk
  }
}

stub_java () {
  stub java 'for arg; do echo "$arg"; done'
}
