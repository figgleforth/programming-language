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

	# Rake splits on commas, so rejoin all arguments. I wouldn't do this anywhere else except for this specific task. It helps me to not have to remember to escape commas when I'm interpreting code using this task.
	full_string = ([args[:string]] + args.extras).join(',')
	pp Ore.interp(full_string)
rescue SystemExit
	# Interrupt exit
rescue Ore::Error => e
	$stderr.puts e.message # Prevents Ruby stack trace from polluting Ore error message
	exit 1
rescue Exception => e
	raise e
end

task :parse, [:string] do |_, args|
	if args[:string].nil? || args[:string].empty?
		raise ArgumentError, "rake parse expected file arguments `bundle exec rake parse[\"Hello!\"]`"
	end

	# Rake splits on commas, so rejoin all arguments. I wouldn't do this anywhere else except for this specific task. It helps me to not have to remember to escape commas when I'm parsereting code using this task.
	full_string = ([args[:string]] + args.extras).join(',')
	pp Ore.parse(full_string)
rescue SystemExit
	# Interrupt exit
rescue Ore::Error => e
	$stderr.puts e.message # Prevents Ruby stack trace from polluting Ore error message
	exit 1
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
rescue Ore::Error => e
	$stderr.puts e.message
	exit 1
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
rescue Ore::Error => e
	$stderr.puts e.message
	exit 1
rescue Exception => e
	raise e
end
