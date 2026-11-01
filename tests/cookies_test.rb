require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# Code::Cookies (ruby/shared/cookies.rb) and lang/password.code. The cookies of a real request are in e2e_server_test.rb.
class Cookies_Test < Base_Test
	SECRET = 'a test secret'

	def test_a_signed_value_keeps_its_type
		[7, 'ada', 1.5, true, false, nil].each do |value|
			assert_equal [true, value], Code::Cookies.verify('user', Code::Cookies.sign('user', value, SECRET), SECRET)
		end
	end

	def test_a_signed_value_does_not_read_with_another_secret_or_another_name
		signed = Code::Cookies.sign 'user', 7, SECRET
		assert_equal [false, nil], Code::Cookies.verify('user', signed, 'another secret')
		assert_equal [false, nil], Code::Cookies.verify('admin', signed, SECRET)
		assert_equal [false, nil], Code::Cookies.verify('user', 'not signed', SECRET)
	end

	def test_a_signed_value_must_fit_in_json
		assert_raises(Code::Invalid_Cookie) { Code::Cookies.sign 'user', Object.new, SECRET }
	end

	# A browser drops SameSite=None without Secure, so it is an error here, not a cookie that silently never comes back.
	def test_same_site_none_needs_secure
		assert_raises(Code::Invalid_Cookie) { Code::Cookies.header 'a', 'b', same_site: 'None' }
		assert_equal 'a=b; Path=/; HttpOnly; Secure; SameSite=None', Code::Cookies.header('a', 'b', secure: true, same_site: 'None')
		assert_raises(Code::Invalid_Cookie) { Code::Cookies.header 'a', 'b', same_site: 'lax' }
	end

	def test_a_value_is_url_encoded_and_decoded
		assert_equal 'note=a%3Bb+c; Path=/; HttpOnly; SameSite=Lax', Code::Cookies.header('note', 'a;b c')
		assert_equal 'a;b c', Code::Cookies.decode('a%3Bb+c')
		assert_equal '%zz', Code::Cookies.decode('%zz')
	end

	def test_after_set_cookies_is_what_the_browser_sends_next
		cookie = Code::Http_Server::Webrick_Cookie
		before = [cookie.new('keep', '1'), cookie.new('change', 'old'), cookie.new('drop', 'x')]
		after  = Code::Cookies.after_set_cookies before, ['change=new; Path=/; HttpOnly', 'drop=; Path=/; Max-Age=0', 'add=2; Path=/']
		assert_equal({ 'keep' => '1', 'change' => 'new', 'add' => '2' }, after.to_h { [it.name, it.value] })
	end

	# Without CODE_SECRET, the key is made once next to the program, only the owner can read it, and the next interpreter (a restart) reads the same key.
	def test_the_cookie_secret_is_kept_next_to_the_program
		saved = ENV.delete 'CODE_SECRET'
		::Dir.mktmpdir do |dir|
			program = ::File.join dir, 'app.code'
			first   = Code::Interpreter.new
			first.instance_variable_set :@main_source_file, program
			secret = nil
			_, err = capture_io { secret = first.cookie_secret }

			path = ::File.join dir, Code::CODE_SECRET_FILE
			assert_match(/\A\h{64}\z/, secret)
			assert_equal secret, ::File.read(path)
			assert_equal 0o600, ::File.stat(path).mode & 0o777
			assert_includes err, path

			second = Code::Interpreter.new
			second.instance_variable_set :@main_source_file, program
			assert_equal secret, second.cookie_secret

			ENV['CODE_SECRET'] = 'from the environment'
			assert_equal 'from the environment', Code::Interpreter.new.cookie_secret
		end
	ensure
		saved ? ENV['CODE_SECRET'] = saved : ENV.delete('CODE_SECRET')
	end

	def test_password_edge_cases
		out = Code.interp <<~CODE
		    @load 'lang/password'

		    empty   := hash_password('')
		    unicode := hash_password('pässwörd 🔑')
		    parts   := unicode.split('$')
		    cheaper := "`parts[0]`$1024$`parts[2]`$`parts[3]`$`parts[4]`$`parts[5]`"

		    [password_matches?('', empty), password_matches?(' ', empty), password_matches?('pässwörd 🔑', unicode), password_matches?('passwörd 🔑', unicode), password_matches?('pässwörd 🔑', cheaper), password_matches?('pässwörd 🔑', unicode.slice(0, 40)), parts.count()]
		CODE
		assert_equal [true, false, true, false, false, false, 6], out.values
	end

	def test_password_hashes
		out = Code.interp <<~CODE
		    @load 'lang/password'

		    hash := hash_password('hunter2')
		    [password_matches?('hunter2', hash), password_matches?('hunter3', hash), hash_password('hunter2') == hash, password_matches?('x', 'not a hash')]
		CODE
		assert_equal [true, false, false, false], out.values
	end
end
