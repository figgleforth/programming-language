require './frontend/token'

PRINT_PADDING   = 35
NEWLINE_ESCAPED = "\\n" # this renders as the literal string '\n'
NEWLINE         = "\n" # this renders as a newline

def say *args
  debug_log = true
  puts *args if debug_log
end

def chars_from_source_file source_file_name
  characters = []
  File.open(ARGV[0] || source_file_name).read.each_char.with_index do |char, index|
    if char == NEWLINE
      characters << NEWLINE_ESCAPED
    else
      characters << char
    end
  end
  characters
end

def numeric? str
  !!(str =~ /\A[0-9]+\z/)
end

def alpha? str
  !!(str =~ /\A[a-zA-Z]+\z/)
end

def alphanumeric? str
  !!(str =~ /\A[a-zA-Z0-9]+\z/)
end

def symbol? str
  !!(str =~ /\A[^a-zA-Z0-9\s]+\z/)
end

def whitespace? char
  char == ' ' || char == "\t"
end

def newline? char
  char == NEWLINE_ESCAPED || char == NEWLINE
end

def maybe_identifier? char
  alpha?(char) || char == '_'
end

def maybe_number? char
  numeric?(char)
end

def maybe_symbol? char
  symbol?(char)
end

def continues_identifier? char
  alphanumeric?(char) || char == '_'# || char == '?'
end

# unused, I think
def eat_until_whitespace
  characters = []
  while !reached_end? && peek != ' ' && peek != "\t" && peek != NEWLINE_ESCAPED
    characters << peek
    @caret.advance_index
  end
  characters.join
end
