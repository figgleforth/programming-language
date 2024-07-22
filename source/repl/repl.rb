require 'readline'
require_relative '../lexer/lexer'
require_relative '../parser/parser'
require_relative '../interpreter/interpreter'
require_relative '../interpreter/scopes'

BULLET_COLOR       = 236
OUTPUT_COLOR       = 240
BULLET_COLOR_ERROR = 88
OUTPUT_COLOR_ERROR = 196
BULLET_COLOR_INTRO = 238
OUTPUT_COLOR_INTRO = 242


class REPL
    attr_accessor :instructions

    # see https://github.com/fidian/ansi for a nice table of colors with their codes
    COLORS = {
               black:         0,
               red:           197,
               green:         2,
               yellow:        3,
               blue:          4,
               magenta:       5,
               cyan:          6,
               white:         7,
               gray:          236,
               light_gray:    240,
               lighter_gray:  244,
               light_red:     9,
               light_green:   10,
               light_yellow:  11,
               light_blue:    12,
               light_magenta: 13,
               light_cyan:    14,
               light_white:   15
             }.freeze

    BULLET = '◼︎'.freeze


    def ansi_color_from_hex hex
        rgb = hex.scan(/../).map { |color| color.to_i(16) }
        "\e[38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m"
    end


    def colorize(foreground, string, background = nil)
        fg_code = if foreground.is_a? Integer
            foreground
        else
            COLORS[foreground&.downcase&.to_sym]
        end
        bg_code = if background.is_a? Integer
            background
        else
            COLORS[background&.downcase&.to_sym]
        end

        ansi_fg = fg_code ? "\e[38;5;#{fg_code}m" : ""
        ansi_bg = bg_code ? "\e[48;5;#{bg_code}m" : ""

        "#{ansi_fg}#{ansi_bg}#{string}\e[0m"
    end


    def prompt
        colorize('lighter_gray', '')
    end


    def for_fun_error_expr_percentage_this_session # just returns % of expressions that did not return an error
        @total_errors.to_f / @total_executed.to_f
    end


    def help_instructions
        @instructions ||= %Q(#{BULLET} exit with \\q or \\x or exit
#{BULLET} continue on next line with \\
#{BULLET} end multiline with ; or an expression
#{BULLET} print current scope with @
#{BULLET} errors print in red
#{BULLET} output prints in gray)
    end


    def repl # I've never needed pry's command count output: `[#] pry(main)>` so I choose not to have a count here. I want the prompt to look simple and clean – the square bullet basically represents output from the REPL
        print colorize('blue', BULLET) + colorize('blue', " \e[1mEmerald REPL\e[0m")
        print colorize('blue', ", type help for tips\n")

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

                if line.strip.downcase == 'help'
                    break

                elsif %w(\q \x exit).include?(line.strip.downcase)
                    # break
                    exit

                elsif line.strip.end_with?('\\') or line.strip.empty?
                    next
                else
                    break # evaluate
                end
            end

            if input.strip.downcase == 'help'
                puts colorize 'blue', help_instructions
                next
            end

            bullet = BULLET_COLOR
            text   = OUTPUT_COLOR
            begin
                tokens            = Lexer.new(input).lex
                ast               = Parser.new(tokens).to_ast
                block             = Block_Expr.new
                block.expressions = ast
                output            = interpreter.evaluate block
            rescue Exception => e
                output = e # to ensure exceptions are printed without crashing the REPL, whether Ruby exceptions or my own for Em
                text   = OUTPUT_COLOR_ERROR
                bullet = BULLET_COLOR_ERROR
            end

            output = 'nil' if output.is_a? Nil_Construct
            if output.is_a? Scopes::Scope # to pretty print the scope from the @ command
                output = PP.pp(output.declarations, '').chomp
            end
            print colorize(bullet, "#{BULLET} ")
            print colorize(text, output)
            puts
        end
    end

end


REPL.new.repl
