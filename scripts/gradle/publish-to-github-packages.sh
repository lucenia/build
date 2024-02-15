#!/bin/bash -eu

# Copyright Lucenia Inc.
#
# SPDX-License-Identifier: Apache-2.0.
# 
# The Lucenia Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# This script was written by @karlvr and available at the following
# location: https://gist.github.com/karlvr/5a4321f9ddf193ceb122849f8fb806d1
#
# Modifications licensed under Apache-2.0.

basedir="${1:-}" # The directory to start looking for poms from
owner="${2:-}" # The owner username on GitHub
repository="${3:-}" # The repository name on GitHub
serverid="${4:-}" # Matches to <server> in ~/.m2/settings.xml

if [ -z "$basedir" -o -z "$owner" -o -z "$repository" -o -z "$serverid" ]; then
  echo "usage: $0 <basedir> <owner> <repository> <serverid>" >&2
  exit 1
fi

trap ctrl_c INT

ctrl_c() {
	echo "Interrupted" >&2
	exit 1
}

# Find poms in artifact and version order
for pom in $(find "$basedir" \( -name '.nexus' \) -prune -false -o -name '*.pom' | sort --version-sort) ; do
	dir=$(dirname $pom)
	dir=$(cd "$dir" && pwd)
	if [ -f "$dir/.migrated-github-packages" ]; then
		continue
	fi

	version=$(basename $dir)
	artifact=$(basename $(dirname $dir))
	jar="$dir/$artifact-$version.jar"
	sources="$dir/$artifact-$version-sources.jar"
	javadoc="$dir/$artifact-$version-javadoc.jar"
	pomfile="$dir/$artifact-$version.pom"

	command="mvn -e -q org.apache.maven.plugins:maven-deploy-plugin:2.4:deploy-file \
		-DrepositoryId=$serverid \
		-Durl=https://maven.pkg.github.com/$owner/$repository"

	if [ -f "$jar" ]; then
		command="$command -Dfile=\"$jar\""
	elif [ -f "$pomfile" ]; then
		command="$command -Dfile=\"$pomfile\""
	fi
	if [ -f "$sources" ]; then
		command="$command -Dsources=\"$sources\""
	fi
	if [ -f "$javadoc" ]; then
		command="$command -Djavadoc=\"$javadoc\""
	fi
	if [ -f "$pomfile" ]; then
		command="$command -DpomFile=\"$pomfile\""
	fi

	echo "$pomfile"

	eval $command
	touch "$dir/.migrated-github-packages"
done
