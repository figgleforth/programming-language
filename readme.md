## .e

A for-fun programming language with some serious and hopefully some whacky mechanics.

See [
`test/helper#interp_file`](./test/helper.rb) to run your own .e files.
```bash
# Make sure you have Ruby 3.4.1 or greater installed.
$ bundle install 
$ bundle exec ruby -Itest -e "Dir['test/**/*_test.rb'].each { require_relative _1 }"

Finished in 0.288138s, 458.1138 runs/s, 2318.3336 assertions/s.
132 runs, 668 assertions, 0 failures, 0 errors, 1 skips
```
Free and open source, with [MIT](./LICENSE.txt).
