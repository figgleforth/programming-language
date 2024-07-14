require_relative '../lexer/lexer'
require_relative '../parser/parser'
require_relative '../interpreter/interpreter'


class String
    COLORS = {
      "black"   => "\e[30m",
      "red"     => "\e[31m",
      "green"   => "\e[32m",
      "yellow"  => "\e[33m",
      "blue"    => "\e[34m",
      "magenta" => "\e[35m",
      "cyan"    => "\e[36m",
      "white"   => "\e[37m",
      "gray"    => "\e[90m"
    }.freeze

    # Method to convert hex color to RGB
    def hex_to_rgb(hex)
        hex.scan(/../).map { |color| color.to_i(16) }
    end


    # Method to convert RGB to ANSI escape code
    def rgb_to_ansi(rgb)
        "\e[38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m"
    end


    def colorize(color)
        ansi_code = COLORS[color.downcase] || rgb_to_ansi(hex_to_rgb(color))
        "#{ansi_code}#{self}\e[0m"
    end
end


@blue  = 'blue'
@green = 'green'
@gray  = 'gray'
puts "——— Type \\q or exit to quit".to_s.colorize(@gray)


def repl
    interpreter = Interpreter.new

    loop do
        print " ƒ  ".colorize(@blue)
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


repl
