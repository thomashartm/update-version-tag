#!/bin/bash

################################################################################
# Description: This script detects the latest semantic versioning compatible 
# tag of the current repoand increments the tag to next major, minor or patch version.
# It also supports branch specific suffixes.
#
# MIT License
#
# Copyright (c) 2023 Thomas Hartmann
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
################################################################################


TAG_PATTERN='^[v]?[0-9]{1,5}\.?[0-9]{0,5}\.?[0-9]{0,5}$'
MAJOR_PREFIX="v"
SUFFIX=""

output_log() {
  echo "$1"
} >&2

update_last_revision() {
  latest_tag=$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' refs/tags | head -n 1)
  output_log "::Current Version::$latest_tag"

  next_version=$(increment_version $latest_tag $1)
  output_log "::Next Version::$next_version"
  echo "::set-output name=next_version::$next_version";
}

show_all_versions() {
  output_log "Getting latest tagged revision ...";
  revisions=$(git tag | grep -E $TAG_PATTERN | wc -l | xargs)
  if [ "$revisions" -eq "0" ]; then
    output_log  "No latest semver tag found"
  else
    output_log  "Found $revisions tags"
    versions=$(git tag | grep -E $TAG_PATTERN | tr -d 'v')
    for $tag in $versions
    do
      output_log $tag
    done
  fi
  echo "::set-output name=tags_list::$versions";
}

get_empty_or_zero(){
  if [ -z "$1" ]
  then
      echo "0"
  else
      echo "$1"
  fi
}

numeric_only(){
  numeric_part=$(echo "$1" | tr -cd '[:digit:]')
  echo $numeric_part
}

increment_version() {
  VERSION_TAG=$1
  UPDATE_TYPE=$2

  IFS='.' read -r -a version_parts <<< "$VERSION_TAG"
  major=${version_parts[0]}
  minor=$(get_empty_or_zero ${version_parts[1]})
  patch=$(get_empty_or_zero ${version_parts[2]})

  #output_log "::current version::$major.$minor.$patch"
  case $UPDATE_TYPE in
    major|2)
      output_log "Updating major version"
      major=$(numeric_only $major)
      major=$((major + 1))
      # Incrementing the major will set minor and patch to 0
      major="$MAJOR_PREFIX$major"
      minor=0
      patch=0
      ;;
    minor|1)
      output_log "Updating minor version"
      # Incrementing the minor will set patch to 0
      minor=$((minor + 1))
      patch=0
      ;;
    *)
      output_log "Updating patch version"
      patch=$((patch + 1))
      ;;
  esac

  if [[  -n "$SUFFIX" ]]; then
    SUFFIX=".$SUFFIX"
  fi

  next_version="$major.$minor.$patch$SUFFIX"
  #output_log "::Next version::$next_version"
  echo $next_version
}

# Check command-line argument
if [[ $# -eq 0 ]]; then
  echo "No command specified. Please provide 'show' or 'update' as an argument."
  exit 1
fi

command=$1

# Execute the appropriate function based on the command
case $command in
  show)
    show_all_versions
    ;;
  update)
    # Check if a tag argument is provided
    if [[ $# -lt 2 ]]; then
      output_log "Please provide the required type of semantic version update. Available options major (2) | minor (1) | patch (0)"
      exit 1
    fi
    UPDATE_TYPE=$2

    if [[ $# -eq 3 ]]; then
      SUFFIX=$3
    fi
    update_last_revision "$UPDATE_TYPE"
    ;;
  *)
    output_log "Invalid command specified. Please provide 'show' or 'update' as an argument."
    exit 1
    ;;
esac
