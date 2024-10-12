#!/bin/sh

. `dirname "$0"`/../_common.sh

if [ ! -f ".ruby-version" ] || [ "$(cat .ruby-version)" != "$(ruby -e "puts RUBY_VERSION")" ]
then
	exe git -C ~/.rbenv/plugins/ruby-build pull

	if [ ! -f ".ruby-version" ]
	then
		echo "File '.ruby-version' not found. Installing last stable version..."
		## https://github.com/rbenv/ruby-build/issues/2054
		latest_version=$(rbenv install -l 2>&1 | grep '^[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+$' | tail -1)
		exe rbenv install -s $latest_version
		exe rbenv local $latest_version
	else
		exe rbenv install -s
	fi
fi

if [ ! -f "Gemfile.lock" ] || [ \
	"$(tail -n 1 Gemfile.lock | tr -d [:blank:])" != \
		"$(bundle -v | cut -d ' ' -f 3)" \
]
then exe gem install bundler --conservative
fi

bundle install
