@.log result # arrow is shorthand for debug printing to console
@.log 'nice' if enabled? # print 'nice' if enabled?
@.log result + 4, "the result is `result`" # takes an array of expressions, prints each on a new line
@.warn 'some warning' # debug print warning
@.error 'some error' # debug print error

###
favorite_thing := @.input

idea; reading from console. when the line with @.input is executed, the program waits for input from the console. when the user presses enter, the input is stored in the variable on the left side of the @.input operator
###


if Emerald was Gem # equivalent to >==, checking if Gem is in the ancestry of Emerald, but not whether Emerald type == Gem type
}
