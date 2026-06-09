source "https://rubygems.org"

# Si Scotia tiene un mirror interno de gems, reemplazar el source de arriba.
gem "fastlane", "~> 2.220"

# Fastlane carga plugins desde este archivo si existe.
plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
