require 'minitest/test_task'
require_relative 'lib/ore'
require 'pp'

task :default => [:test, :cloc]

Minitest::TestTask.create(:test) do |t|
	t.libs << 'test'
	t.warning    = false
	t.test_globs = ['test/**/*_test.rb']
end

task :cloc do
	sh "\ncloc --quiet --force-lang-def=ore.cloc ."
end

task :interp, [:string] do |_, args|
	if args[:string].nil? || args[:string].empty?
		raise ArgumentError, "rake interp expected file arguments `bundle exec rake interp[\"Hello!\"]`"
	end

	pp Ore.interp(args[:string].to_s)
rescue SystemExit
	# Interrupt exit
rescue Exception => e
	raise e
end

task :interp_file, [:file] do |_, args|
	if args[:file].nil? || args[:file].empty?
		raise ArgumentError, "rake interp_file expected file arguments `bundle exec rake interp_file[file]`"
	end

	pp Ore.interp_file(args[:file])
rescue SystemExit
	# Interrupt exit
rescue Exception => e
	raise e
end

task :dev, [:file] do |_, args|
	if args[:file].nil? || args[:file].empty?
		raise ArgumentError, "rake dev expected file arguments `bundle exec rake dev[file]`"
	end

	Ore.interp_file_with_hot_reload args[:file]
rescue SystemExit
	# Interrupt exit
rescue Exception => e
	raise e
end
