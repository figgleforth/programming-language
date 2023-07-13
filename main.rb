require './frontend/language.rb'
require './frontend/token.rb'

@tokens                     = []
@words                      = []
@line_number                = 0
@char_number                = 0
@last_token                 = nil
@number_of_whitespaces_seen = 0

File.open('./language/test.lang').read.each_line.with_index do |line_of_code, line_number|
  puts "\n##############################"
  # puts "line_of_code: #{line_of_code}\n"

  @line_number = line_number
  @words       = line_of_code.split(' ')
  puts "words: #{@words}"

  line_of_code.split('') do |char, char_number|
    @char_number = char_number

    # hint) there's a whitespace between each word, so 0 whitespaces seen = first word, 1 whitespaces seen = second word, etc. each time char == ' ' this is virtually the loop when looping words. this if is the equivalent of the block passed to to words.each
    if char == ' '
      @number_of_whitespaces_seen += 1
      next
    end

    last_word = @words[@number_of_whitespaces_seen - 1]
    this_word = @words[@number_of_whitespaces_seen]
    next_word = @words[@number_of_whitespaces_seen + 1]

    # puts "char: #{char}"
    # puts "this_word: #{this_word} -> #{this_word.class}"

    token = Token.new

    token.first_char       = this_word[0]
    token.last_char        = this_word[-1]
    token.second_char      = this_word[1]
    token.second_last_char = this_word[-2]

    token.raw_line       = line_of_code
    token.raw_word       = this_word
    token.formatted_word = this_word # todo) format for things like type

    token.is_pre_type = Language::Keywords[:pre_type].include?(token.last_char) # todo) to method
    token.is_type     = Language::Keywords[:types].include?(token.formatted_word) # todo) to method

    @tokens << token
  end
end

puts @tokens.inspect
