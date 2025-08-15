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

task :check_for_intrinsics_implementations do
	# Ensures that all `air/intrinsics/*.air` files have implementations in `lib/intrinsics/*.rb`, whose names match and file extensions differ.

	missing = []
	Dir.new('air/intrinsics').each_child do |it|
		next unless it.end_with? '.air'

		implementation_file = "#{it[..-5]}.rb"

		unless File.exist?("lib/intrinsics/#{implementation_file}")
			missing << implementation_file
		end
	end

	unless missing.empty?
		raise "Missing implementation for these intrinsics:\n#{missing.join(', ')}"
	end
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
