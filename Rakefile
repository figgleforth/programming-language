require 'minitest/test_task'
require_relative 'lib/ore'
require 'pp'

def _interp source_code
	Ore.interp source_code
end

def _interp_file filepath
	code        = File.read filepath
	global      = Ore::Global.with_standard_library
	interpreter = Ore::Interpreter.new Ore.parse(code), global
	result      = interpreter.output

	# If servers were started, wait for them and setup signal handlers
	if interpreter.context.servers.any?
		servers = interpreter.context.servers

		Signal.trap 'INT' do
			puts "\nShutting down servers..."
			servers.each(&:stop)
			exit 0
		end

		Signal.trap 'TERM' do
			puts "\nShutting down servers..."
			servers.each(&:stop)
			exit 0
		end

		puts "Server(s) running. Press Ctrl+C to stop."
		servers.each do |server|
			server.server_thread&.join
		end
	end

	result
end

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

	pp _interp(args[:string].to_s)
rescue SystemExit
	# Interrupt exit
rescue Exception => e
	raise "This seems to be broken... Do tests pass? Try `rake`.\n#{e}"
end

task :interp_file, [:file] do |_, args|
	if args[:file].nil? || args[:file].empty?
		raise ArgumentError, "rake interp_file expected file arguments `bundle exec rake interp_file[file]`"
	end

	pp _interp_file(args[:file])
rescue SystemExit
	# Interrupt exit
rescue Exception => e
	raise "This seems to be broken... Do tests pass? Try `rake`.\n#{e}"
end
