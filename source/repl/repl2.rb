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


f_symbol_color = "22C5FE"
equals_color   = "8A8878"
output_color   = "8A8878"


def repl(f_symbol_color, equals_color, output_color)
    fn_ansi     = rgb_to_ansi(hex_to_rgb(f_symbol_color))
    equals_ansi = rgb_to_ansi(hex_to_rgb(equals_color))
    output_ansi = rgb_to_ansi(hex_to_rgb(output_color))
    interpreter = Interpreter.new

    loop do
        print " ƒ  ".colorize(fn_ansi)
        input = gets.chomp
        break if %w(\q exit).include? input.downcase

        print "    ".colorize(equals_ansi)

        begin
            tokens = Lexer.new(input).lex
            ast    = Parser.new(tokens).to_ast
            output = interpreter.evaluate ast.first
        rescue Exception => e
            output = e
        end

        if output
            output = output.to_s.colorize(output_ansi)
        end

        puts output
    end
end


repl(f_symbol_color, equals_color, output_color)
