require 'minitest/test_task'
require_relative 'source/main'
require 'pp'

task :default => [:test, :cloc]

Minitest::TestTask.create(:test) do |t|
	t.libs << 'tests'
	t.warning    = false
	t.test_globs = ['tests/**/*_test.rb']
end

task :cloc do
	sh "\ncloc --quiet --force-lang-def=.config/code.cloc --exclude-dir=.projects,.working,.temporary,tests ."
end
