ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Allow disabling bootsnap when native extensions (like msgpack) don't match the
# current Ruby version, e.g. when running maintenance tasks in CI.
require "bootsnap/setup" unless ENV["DISABLE_BOOTSNAP"] == "1"
