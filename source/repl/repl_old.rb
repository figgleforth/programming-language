require_relative '../lexer/lexer'
require_relative '../parser/parser'

class REPL
    attr_accessor :lexer, :parser, :commands_executed

    SPACE = ' '

    def initialize
        @commands_executed = 1
        @lexer             = Lexer.new
        @parser            = Parser.new
    end


    def run_repl
        while true
            # for the label that shows which command number this is
            commands_width    = @commands_executed.to_s.length
            command_count     = "#{@commands_executed}".rjust commands_width
            @commands_executed += 1

            print "#{command_count})\n\n"
            input = gets.chomp
            break if input == "exit"

            # Print the input back
            repeater = '-'
            repeated = repeater.rjust [commands_width, 1].min.to_i, repeater
            prefix   = repeated.rjust commands_width

            # Execute and print the result of the input
            begin
                lexer.source = input

                parser = Parser.new
                parser.buffer = lexer.lex
                # tokens = scanner.string_to_tokens input

                puts
                puts parser.parse_until
                # puts "∎"
                puts
            rescue StandardError => e
                puts "Error: #{e.message}"
            end
        end
    end
end

REPL.new.run_repl
