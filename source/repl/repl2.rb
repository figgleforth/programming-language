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


@blue          = "22C5FE"
@comment_green = "3BB037"
@gray          = "8A8878"


def repl
    fn_ansi     = rgb_to_ansi(hex_to_rgb(@comment_green))
    output_ansi = rgb_to_ansi(hex_to_rgb(@gray))
    interpreter = Interpreter.new

    loop do
        print " ƒ  ".colorize(fn_ansi)
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

        print " ■  ".colorize(output_ansi)
        construct ||= construct.inspect
        puts construct.to_s.colorize(output_ansi)
    end
end


repl
