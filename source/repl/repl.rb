require_relative '../lexer/lexer'
require_relative '../parser/parser'
require_relative '../interpreter/interpreter'

# Method to convert hex color to RGB
def hex_to_rgb(hex)
    hex.scan(/../).map { |color| color.to_i(16) }
end


# Method to convert RGB to ANSI escape code
def rgb_to_ansi(rgb)
    "\e[38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m"
end


# Method to wrap text in ANSI escape code
class String
    def colorize(ansi_code)
        "#{ansi_code}#{self}\e[0m"
    end
end


@blue          = rgb_to_ansi(hex_to_rgb("22C5FE"))
@comment_green = rgb_to_ansi(hex_to_rgb("3BB037"))
@gray          = rgb_to_ansi(hex_to_rgb("8A8878"))


def repl
    interpreter = Interpreter.new

    loop do
        print " ƒ  ".colorize(@comment_green)
        input = gets.chomp
        next unless input.size > 0
        break if %w(\q exit).include? input.downcase

        begin
            tokens    = Lexer.new(input).lex
            ast       = Parser.new(tokens).to_ast
            construct = interpreter.evaluate ast.first
        rescue Exception => e
            construct = e
        end

        print " ■  ".colorize(@gray)
        construct ||= construct.inspect
        puts construct.to_s.colorize(@gray)
    end
end


puts "——— Type \\q or exit to quit".to_s.colorize(@gray)
repl
