require 'readline'
require_relative '../lexer/lexer'
require_relative '../parser/parser'
require_relative '../interpreter/runtime'
require_relative '../interpreter/scopes'
require_relative '../interpreter/constructs'

BULLET_COLOR       = 'blue'
OUTPUT_COLOR       = 'blue'
BULLET_COLOR_ERROR = 'red'
OUTPUT_COLOR_ERROR = 'red'
BULLET_COLOR_INTRO = 'green'
OUTPUT_COLOR_INTRO = 'green'


class REPL
    attr_accessor :instructions, :total_executed, :total_errors

    # see https://github.com/fidian/ansi for a nice table of colors with their codes
    COLORS = {
               black:         0,
               red:           1,
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


    def initialize
        @total_executed = 0
        @total_errors   = 0
    end


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


    def for_fun_error_expr_percentage_this_session # just returns % of expressions that did not return an error
        return "no expressions evaluated yet" if total_executed == 0
        percent = Integer((total_errors.to_f / total_executed.to_f) * 100).round
        "#{percent}% expressions failed (#{total_errors} of #{total_executed})"
    end


    def help_instructions
        @instructions ||= %Q(#{BULLET} exit with \\q or \\x or exit
#{BULLET} press enter to interpret expression
#{BULLET} outputs print in gray
#{BULLET} errors print in red
#{BULLET} type cd Class to enter its scope
#{BULLET} type cd .. to exit the scope
#{BULLET} type ``` then enter to enable block mode
#{BULLET} type ``` again to exit block mode
#{BULLET} type ls to see your scope
#{BULLET} type ls! to see the stack
#{BULLET} type stats for fun
#{BULLET} type help for tips)
    end


    def print_help
        puts colorize OUTPUT_COLOR_INTRO, "\e[1m#{help_instructions}\e[0m"
    end


    def repl # I've never needed pry's command count output: `[#] pry(main)>` so I choose not to have a count here. I want the prompt to look simple and clean – the square bullet basically represents output from the REPL
        print colorize(BULLET_COLOR_INTRO, "#{BULLET} \e[1mEmerald REPL, press enter now for tips\e[0m\n") # + colorize('blue', " \e[1mEmerald REPL\e[0m")
        # print colorize('blue', ", type help for tips\n")

        # Pressing tab twice prints the current directory, this prevents that:
        Readline.completion_append_character = nil
        Readline.completion_proc             = proc { |s| "   " }

        # Intercept ctrl+c aka interrupt, and exit gracefully without printing a trace
        trap('INT') { exit }

        runtime    = Runtime.new
        block_mode = false

        loop do
            bullet = BULLET_COLOR
            text   = OUTPUT_COLOR

            input = ''
            loop do
                line = Readline.readline('', true)

                if line.strip.downcase == 'help'
                    print_help
                    break

                elsif %w(\q \x exit).include?(line.strip.downcase)
                    exit

                elsif line.strip.end_with?('```')
                    block_mode = !block_mode
                    block_mode ? next : break
                else
                    input += line + "\n"
                    break unless block_mode
                end
            end

            @total_executed += 1

            if (total_executed == 1 and input == "\n") or input.strip.downcase == 'help'
                print_help
                next
            end

            if input.strip.downcase == 'stats'
                print colorize(bullet, "#{BULLET} ")
                puts colorize(text, for_fun_error_expr_percentage_this_session)
                next
            end

            begin
                tokens = Lexer.new(input).lex
                ast    = Parser.new(tokens).to_ast
                output = runtime.evaluate_expressions ast
            rescue Exception => e
                # raise e
                @total_errors += 1
                output        = e.message # to ensure exceptions are printed without crashing the REPL, whether Ruby exceptions or my own for Em
                text          = OUTPUT_COLOR_ERROR
                bullet        = BULLET_COLOR_ERROR
            end

            output          = 'nil' if output == Nil_Expr

            if output.respond_to? :include? and output.include? "\n"
                split = output.split("\n")
                split.each do |part|
                    print colorize(bullet, "#{BULLET} ")
                    print colorize(text, part)
                    puts
                end
            else
                print colorize(bullet, "#{BULLET} ")
                print colorize(text, output)
                puts
            end
        end
    end

end


REPL.new.repl
