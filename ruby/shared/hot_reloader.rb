module Code
	# Runs a `.code` entry file and, if it starts a server, keeps the process alive and re-runs the
	# whole file whenever any watched `.code` changes on prog. Each cycle is a brand-new Interpreter
	# (all instance state reset for free) plus a drop of the class-level lex/parse caches -- no
	# partial state to reconcile. The server's port is reused across reloads.
	#
	# A file that never starts a server behaves exactly as before: run once, return, no watching.
	#
	# Opt-in `reload:` mode (for developing the engine itself, not ordinary `.code` programs): also
	# watches every `.rb` file under `ruby/`, and restarts the whole process on any change instead
	# of reloading in place -- a changed `.rb` file is already loaded into this process, so nothing
	# short of a real restart picks up the new Ruby source.
	class Hot_Reloader
		# @param [Boolean] reload opt-in dev mode: also watch `.rb` files across all of `ruby/`, and
		#   on any change, restart the whole process (`exec`) instead of just re-running the entry file
		#   in place. Needed for a `.rb` edit to matter at all -- see the comment on `run`'s `:change`
		#   branch below.
		def initialize entry_filepath, reload: false
			@entry   = ::File.expand_path entry_filepath
			@reload = reload
			@events  = Queue.new # fed [:change] by Listen and [:shutdown] by the INT/TERM trap
		end

		# @return [[Code::Interpreter, Object]] the interpreter and its last output, for a one-shot
		#   script; [nil, nil] once a server session ends via ^C.
		def run
			$stdout.sync = true # a watch process should print reload/announce lines as they happen

			loop do
				interpreter, result, error = run_entry
				@is_server_app ||= !!interpreter&.servers&.any?

				unless @is_server_app
					raise error if error
					return [interpreter, result]
				end

				error ? report_error(error) : announce(interpreter)
				install_signal_traps
				start_watching

				case @events.pop.first
				when :shutdown
					interpreter&.shutdown_all_servers
					@listener&.stop
					puts "\n\s\s(V) (;,,;) (V)"
					return [nil, nil]
				when :change
					interpreter&.shutdown_all_servers
					if @reload
						# A changed `.rb` file is already `require`d and cached in $LOADED_FEATURES --
						# re-running the entry file in place (the else branch below) would still execute
						# against the *old* class definitions. Only a real process restart picks up new
						# Ruby source. `[$0, $0]` is the two-element exec form (skips a subshell);
						# `ARGV` is the original top-level argv this process itself was started with, so
						# the new process gets the same file/flags and re-enters reload mode too.
						@listener&.stop
						puts Code::Ascii.dim '↻ restarting process'
						exec [$0, $0], *ARGV
					else
						Code::Interpreter.reset_file_caches!
						puts Code::Ascii.dim '↻ reloading'
					end
				end
			end
		end

		private

		# @return [[Code::Interpreter, Object, Exception, nil]]
		def run_entry
			interpreter                     = Code::Interpreter.new
			interpreter.serve_in_foreground = false # this class owns the wait loop, not Interpreter#run
			interpreter.live_reload         = true  # mount /_lang/live-reload + inject its client script;
			#                                         each cycle's fresh Interpreter carries a new token,
			#                                         which is what tells the browser to refresh

			source = ::File.read @entry
			interpreter.register_source @entry, source
			interpreter.run source
			[interpreter, interpreter.last_output, nil]
		rescue Code::Error, Errno::ENOENT => e
			[interpreter, nil, e]
		end

		def announce interpreter
			interpreter.servers.each do |server|
				puts "Code server `#{server.name}` on http://localhost:#{server.port}"
			end
			if @reload
				puts Code::Ascii.dim 'watching .code and .rb files — ^C to stop (any change restarts the process)'
			else
				puts Code::Ascii.dim 'watching .code files — ^C to stop (browser auto-refreshes on save)'
			end
		end

		def report_error error
			$stderr.puts error.message
			$stderr.puts Code::Ascii.dim 'save a fix to retry'
		end

		def install_signal_traps
			return if @traps_installed
			@traps_installed = true
			# Push from a fresh thread -- Queue#push straight from trap context is not guaranteed safe.
			%w[INT TERM].each do |signal|
				Signal.trap(signal) { Thread.new { @events << [:shutdown] } }
			end
		end

		def start_watching
			return if @listener
			require 'listen'
			pattern   = @reload ? /\.(code|rb)\z/ : /\.code\z/
			@listener = Listen.to(*watch_dirs, only: pattern) do |modified, added, removed|
				@events << [:change] unless (modified + added + removed).empty?
			end
			@listener.start
		end

		# Default: the stdlib dir (the user edits `lang/*.code` too) plus the entry file's
		# own dir when that sits outside it. `reload`: the whole `ruby/` tree instead (`.rb` included
		# there, see `start_watching`'s pattern) -- still plus the entry file's own dir, same as
		# default, since a program outside `ruby/` (the common case) needs its own edits watched too.
		# Listen watches recursively either way.
		def watch_dirs
			base_dir = ::File.join(Code::ROOT_PATH, @reload ? 'ruby' : 'lang')
			entry_dir = ::File.dirname(@entry)
			dirs      = [base_dir]
			dirs << entry_dir unless entry_dir == base_dir || entry_dir.start_with?("#{base_dir}/")
			dirs
		end
	end
end
