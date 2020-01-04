#!/bin/bash

#
# Requirements:
#
# ensure python3 is available:
if [[ ! $(command -v python3) ]]; then
  echo "This script requires python3, and some other libraries:"
  echo "  brew install python3 cairo pango gdk-pixbuf libffi"
  echo "Exiting."
  exit 0
fi
#
# If on mac, ensure we have gnu coreutils for command compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
  if [[ ! $(command -v gdate) ]] || [[ ! $(command -v gsed) ]]; then
    echo "This script requires coreutils and gnu-sed to be installed on Mac:"
    echo "  brew install coreutils gnu-sed"
    echo "Exiting."
    exit 0
  fi
  # once gnu coreutils and gnu-sed are installed, we can ensure they are
  # first in the path, for convenience
  corepath="/usr/local/opt/coreutils/libexec/gnubin"
  sedpath="/usr/local/opt/gnu-sed/libexec/gnubin"
  export PATH="$sedpath:$corepath:$PATH"
fi
#
# ensure language packs are installed. e.g. for French
#> sudo apt-get install language-pack-fr
#

# set the default locale for the build
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# perform all actions relative to the path of this script
SCRIPT_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$SCRIPT_DIR" ]]; then
  SCRIPT_DIR="$PWD"
else
  cd $SCRIPT_DIR
  SCRIPT_DIR="$PWD"
fi

# pushing docs to localisation platform (transifex) is only done on Jenkins
LOCALISE=0
if [[ `id -un` == "jenkins" ]]; then
  # and only where configured
  if [ -f ~/.transifexrc ]; then LOCALISE=1; fi
fi

# set up the python environment
if [ ! -d "venv" ]; then
    source venv_setup
fi
source ./venv/bin/activate

# script variables
src="$SCRIPT_DIR/src/commonmark/en"
TMPBASE="$SCRIPT_DIR/tmp"
tmp="$TMPBASE/en"
localisation_root="$SCRIPT_DIR/target/commonmark"

# clear the output directories
rm -rf $TMPBASE
mkdir -p $TMPBASE
rm -rf $localisation_root
mkdir -p $localisation_root

# include helper functions
. "$SCRIPT_DIR/lib/doc_functions.sh"

# generate function called for each document
generate(){
    name=$1
    subdir=$2
    selection=$3
    if [ ! $selection ]
    then
      selection="both"
    fi
    lang=en
    locale=en_UK

    echo "+--------------------------------------------------------"
    echo "| Processing: $name"
    echo "+--------------------------------------------------------"

    assemble $name
    # go to the temp directory and build the documents - put output in target directory
    build_docs $name $subdir $selection $lang $locale

    # update transifex from latest source files
    update_localizations $name

}


# comment as you wish
# format:
#$> generate <doc name> <chapters subfolder> ["html","pdf","both"]
mkdir $tmp
cp -a $src/resources/mkdocs/* $tmp/
myml=$tmp/mkdocs.yml

echo "    - User:" >> $myml
generate "dhis2_user_manual_en" "user"
generate "dhis2_end_user_manual" "end-user"
generate "dhis2_bottleneck_analysis_manual" "bna-app"
generate "dhis2_scorecard_manual" "scorecard-app"

echo "    - Implementer:" >> $myml
generate "dhis2_implementation_guide" "implementer"
generate "dhis2_android_capture_app" "android-app"
generate "user_stories_book" "user-stories"

echo "    - Developer:" >> $myml
generate "dhis2_developer_manual" "developer"
echo "        DHIS2 API Javadocs: https://docs.dhis2.org/<version>/javadoc/" >> $myml
generate "dhis2_android_sdk_user_guide" "android-sdk"

echo "    - Sysadmin:" >> $myml
generate "dhis2_system_administration_guide" "sysadmin"

pushd $tmp
  pushd docs
    ln -s ../resources .
  popd
  rm -rf resources/mkdocs
  mkdocs build --dirty
popd

generate "dhis2_draft_chapters" "draft"

rm -rf $tmp
