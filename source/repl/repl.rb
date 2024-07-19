require 'readline'
require_relative '../lexer/lexer'
require_relative '../parser/parser'
require_relative '../interpreter/interpreter'


class REPL
    COLORS = {
      black:         0,
      red:           1,
      green:         2,
      yellow:        3,
      blue:          4,
      magenta:       5,
      cyan:          6,
      white:         7,
      gray:          8,
      light_red:     9,
      light_green:   10,
      light_yellow:  11,
      light_blue:    12,
      light_magenta: 13,
      light_cyan:    14,
      light_white:   15
    }.freeze

    BULLET = '◼︎'.freeze


    def hex_to_rgb(hex)
        hex.scan(/../).map { |color| color.to_i(16) }
    end


    def rgb_to_ansi(rgb)
        "\e[38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m"
    end


    def colorize(foreground, string, background = nil)
        fg_code = COLORS[foreground&.downcase&.to_sym]
        bg_code = COLORS[background&.downcase&.to_sym]

        ansi_fg = fg_code ? "\e[38;5;#{fg_code}m" : ""
        ansi_bg = bg_code ? "\e[48;5;#{bg_code}m" : ""

        "#{ansi_fg}#{ansi_bg}#{string}\e[0m"
    end


    def prompt
        colorize('gray', '')
    end


    def repl # I've never needed pry's command count output: `[#] pry(main)>` so I choose not to have a count here. I want the prompt to look simple and clean – the square bullet basically represents output from the REPL

        help0 = "#{BULLET} exit with \\q or \\x or exit"
        help1 = "#{BULLET} continue on next line with \\"
        help2 = "#{BULLET} end multiline with ; or an expression"
        help3 = "#{BULLET} print current scope with `@s`"
        puts colorize('gray', "#{help0}\n#{help1}\n#{help2}\n#{help3}\n")

        interpreter = Interpreter.new

        # Pressing tab twice prints the current directory, this prevents that:
        Readline.completion_append_character = nil
        Readline.completion_proc             = proc { |s| nil }

        # Intercept ctrl+c aka interrupt, and exit gracefully without printing a trace
        trap('INT') { exit }

        loop do
            input = ''
            loop do
                line  = Readline.readline('', true)
                input += line + "\n"

                if %w(\q \x exit).include?(line.strip.downcase)
                    # break
                    exit

                elsif line.strip.end_with?('\\') or line.strip.empty?
                    next
                else
                    break # evaluate
                end
            end

            color  = 'gray' # for output foreground
            begin
                tokens            = Lexer.new(input).lex
                ast               = Parser.new(tokens).to_ast
                block             = Block_Expr.new
                block.expressions = ast
                output            = interpreter.evaluate block
            rescue Exception => e
                output = e # to ensure exceptions are printed without crashing the REPL, whether Ruby exceptions or my own for Em
                color  = 'red'
            end

            output = 'nil' if output.is_a? Nil_Construct
            output = colorize(color, output.to_s)

            puts colorize(color, "#{BULLET} #{output}")
        end
    end

end


REPL.new.repl
