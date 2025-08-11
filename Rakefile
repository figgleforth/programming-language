require 'minitest/test_task'
require './code/ruby/shared/helpers'
require 'pp'

task :default => [:test, :cloc]

Minitest::TestTask.create(:test) do |t|
	t.libs << 'test'
	t.warning    = false
	t.test_globs = ['tests/**/*_test.rb']
end

task :cloc do
	sh "\ncloc --quiet --force-lang-def=air.cloc ."
end

task :interp, [:string] do |_, args|
	if args[:string].nil? || args[:string].empty?
		raise ArgumentError, "rake interp expected file arguments `bundle exec rake interp[\"Hello!\"]`"
	end

	pp _interp(args[:string].to_s)
rescue Exception => e
	raise "This seems to be broken... Do tests pass? Try `rake`.\n#{e}"
end

task :interp_file, [:file] do |_, args|
	if args[:file].nil? || args[:file].empty?
		raise ArgumentError, "rake interp_file expected file arguments `bundle exec rake interp_file[file]`"
	end

	pp _interp_file(args[:file])
rescue Exception => e
	raise "This seems to be broken... Do tests pass? Try `rake`.\n#{e}"
end
