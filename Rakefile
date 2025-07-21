require 'minitest/test_task'
require './src/shared/helpers'
require 'pp'

task :default => [:test, :cloc]

Minitest::TestTask.create(:test) do |t|
	t.libs << 'test'
	t.warning    = false
	t.test_globs = ['test/**/*_test.rb']
end

task :cloc do
	sh "\ncloc --quiet --force-lang-def=emerald.cloc ."
end

task :interp, [:file] do |_, args|
	if args[:file].nil? || args[:file].empty?
		raise ArgumentError, "rake interp expected file arguments `bundle exec rake interp[path_to_file]`"
	end

	pp _interp_file args[:file]
end
