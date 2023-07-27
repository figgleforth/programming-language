require 'ostruct'

source   = File.open(ARGV[0] || './hatch/hatch_spec.txt')
@program = source.read.each_char.with_index.to_a.map! do |char, index|
  OpenStruct.new(char: char, index: index)
end
source.close

@other      = [' ', "\n", '=']
@literals   = %w|true false nil|
@keywords   = %w|enum def end if else while for obj api < > self new private public . ,|
@operators  = %w(+ - * / % = == != < > <= >= && || ~> ~~> ~~~> @@ @).sort_by(&:length).reverse
@delimiters = %w({ } [ ] : ; , . .. ?).sort_by(&:length).reverse + %w[( )]

@words       = []
@word_so_far = ''

def number?(char)
  char.to_i != 0 || char == '0'
end

def decimal_point?(char)
  char == '.'
end

def delimeter?(char)
  @delimiters.include?(char) || @other.include?(char)
end

def commit_word
  return if @word_so_far.strip.empty?
  @words << OpenStruct.new(word: @word_so_far.strip)#, indent: @indents)
  @word_so_far = ''
  @indents     = 0
  # puts "+W #{@words.last.word}"
end

def commit_comment
  return if @word_so_far.strip.empty?
  @words << OpenStruct.new(word: @word_so_far.strip, type: :comment)
  @word_so_far = ''
  @indents     = 0
end

def commit_newline
  return if @word_so_far.strip.empty?
  @words << OpenStruct.new(word: "eol", type: :newline)
  @word_so_far = ''
  @indents     = 0
end

def commit_char(char)
  @words << OpenStruct.new(word: char.strip)
  printable_word = @words.last.word.gsub("\n", '\\n')
  # puts '+C ' + printable_word
end

def accumulate_word(char)
  @word_so_far += char
end

@indents                    = 0
parsing_comment             = false
parsing_single_quote_string = false
parsing_double_quote_string = false
parsing_decimal_number      = false
@program.each do |caret|
  it = caret.char
  at = caret.index

  if parsing_comment
    # stay in comment until a newline
    accumulate_word it
    parsing_comment = caret.char != "\n"

    if !parsing_comment
      commit_comment
      commit_newline
    end
    next
  end

  if parsing_single_quote_string
    # stay in quote until end single quote
    parsing_single_quote_string = caret.char != "'"
    next
  end

  if parsing_double_quote_string
    # stay in quote until end single quote
    parsing_double_quote_string = caret.char != '"'
    next
  end

  if number?(it) || (it == '.' && number?(@word_so_far[-1]))
    accumulate_word(it)
    next
  end

  if it == "'"
    parsing_single_quote_string = true
    next
  end

  if it == '"'
    parsing_double_quote_string = true
    next
  end

  if it == '#'
    # skip all the way until the next newline
    parsing_comment = true
    next
  end

  if it == ' '
    @indents += 1 if @word_so_far.strip.empty?
    commit_word
    next
  end

  if it == "\n" && @words&.last&.word == "\n"
    next
  end

  if it == "\n"
    commit_word
    commit_newline
    next
  end

  if it == '/' && @words&.last&.word == '/'
    @words.last.word += it
    # commit_char '/'
    next
  elsif it == '/'
    commit_word
    commit_char(it)
    next
  end

  if it == '=' && @words&.last&.word == '='
    @words.last.word += it
    next
  end

  if !delimeter?(it)
    accumulate_word(it)
    next
  elsif @keywords.include?(@word_so_far)
    commit_word
    accumulate_word(it)
  else
    commit_word
    commit_char(it)
  end
end

commit_word # commit any remaining word

last_index_checked = 0
# @words.each_with_index do |word, index|
#   if word.word == 'eol'
#     debug = @words[last_index_checked..index].map do |w|
#       next if w.type == :comment || w.type == :eol
#       _word = if w.word == 'eol'
#                 w.word.gsub('eol', '')
#               else
#                 w.word
#               end
#
#       # indent = "".tap do |str|
#       #   (w.indent || 0).times do
#       #     str << " "
#       #   end
#       # end
#
#       _word
#     end
#
#     # puts debug.join ' '
#
#     last_index_checked = index
#     next
#   end
# end

@words = @words.reject do |word|
  word.type == :comment || word.type == :eol
end

puts @words.map &:word
