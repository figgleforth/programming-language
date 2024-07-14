require 'readline'
require_relative '../lexer/lexer'
require_relative '../parser/parser'
require_relative '../interpreter/interpreter'


class REPL
    COLORS = {
      black:   "\e[30m",
      red:     "\e[31m",
      green:   "\e[32m",
      yellow:  "\e[33m",
      blue:    "\e[34m",
      magenta: "\e[35m",
      cyan:    "\e[36m",
      white:   "\e[37m",
      gray:    "\e[38;2;120;120;120m"
    }.freeze


    def initialize
        puts colorize('gray', "■  Type \\q or exit to quit".to_s)
    end


    def hex_to_rgb hex
        hex.scan(/../).map { |color| color.to_i(16) }
    end


    def rgb_to_ansi rgb
        "\e[38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m"
    end


    def colorize color, string
        ansi_code = COLORS[color&.downcase&.to_sym] || rgb_to_ansi(hex_to_rgb(color))
        "#{ansi_code}#{string}\e[0m"
    end


    def prompt
        colorize('green', "❯  ")
    end


    # note: I've never needed pry's command count output: `[#] pry(main)>` so I choose not to have a count here. I want the prompt to be as simple as possible
    def repl
        interpreter = Interpreter.new

        trap("INT") { puts; print(prompt) } # when

        loop do
            # print(prompt)
            # input = gets.chomp
            input = Readline.readline(prompt, true)
            next unless input.size > 0
            break if %w(\q exit).include? input.downcase

            begin
                color  = 'gray'
                tokens = Lexer.new(input).lex
                ast    = Parser.new(tokens).to_ast
                output = interpreter.evaluate ast.first # the value of the program
            rescue Exception => e # todo: commented for now so I can catch errors
                output = e
                color  = 'red'
            end

            print colorize(color, "■  ")
            output ||= output.inspect
            puts colorize(color, output.to_s)
        end
    end

end


REPL.new.repl
