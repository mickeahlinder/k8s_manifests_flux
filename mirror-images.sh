#!/bin/bash
set -o pipefail

trap '
  trap - INT # restore default INT handler
  kill -s INT "$$"
' INT

IMAGES_FILE="$1"

HOST_PROJECT_TAG_PATTERN="^([^/]*)/([^/]*)/(.*)?:(.*)$"
PROJECT_TAG_PATTERN="^([^/]*)/(.*)?:(.*)$"
TAG_PATTERN="^(.*):(.*)$"

REPOSITORY="pubimgcache"
REPOSITORY_URL="$REPOSITORY.azurecr.io"

c_red=$(tput setaf 1)
c_green=$(tput setaf 2)
c_cyan=$(tput setaf 6)
c_white=$(tput setaf 7)
c_grey=$(tput setaf 8)
c_normal=$(tput sgr0)

function process_image() {
  local fullUri=$1
  local project=$2
  local repository=$3
  local tag=$4

  printf "%s" "Processing ${c_cyan}$fullUri...${c_normal}"

  local targetRepository
  if [ -z "$project" ]; then
    targetRepository="$repository"
  else
    targetRepository="$project/$repository"
  fi

  if ! az acr repository show-tags --name $REPOSITORY --repository $targetRepository 2> /dev/null |
jq -e 'index('\"$tag\"')' > /dev/null; then
    printf "%s\n" "${c_white}[${c_red}missing${c_white}]${c_normal}"

    printf "${c_grey}docker pull %s${c_normal}\n" "$fullUri"
    docker pull $fullUri

    printf "${c_grey}docker tag %s %s/%s:%s \n${c_normal}\n" "$fullUri" "$REPOSITORY_URL" "$targetRepository" "$tag"
    docker tag $fullUri $REPOSITORY_URL/$targetRepository:$tag

    printf "${c_grey}docker push %s/%s:%s${c_normal}\n" "$REPOSITORY_URL" "$targetRepository" "$tag"
    docker push $REPOSITORY_URL/$targetRepository:$tag
  else
    printf "%s" "${c_white}[${c_green}exists${c_white}]${c_normal}"
  fi
}

while IFS="" read -r p || [ -n "$p" ]
do
  if [[ $p =~ $HOST_PROJECT_TAG_PATTERN ]]
  then
    process_image $p ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[4]}
  elif [[ $p =~ $PROJECT_TAG_PATTERN ]]
  then
    process_image $p ${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}
  elif [[ $p =~ $TAG_PATTERN ]]
  then
    process_image $p "" ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}
  fi

  printf "\n"
done < $IMAGES_FILE
