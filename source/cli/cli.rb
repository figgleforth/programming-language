if ARGV.empty?
    puts "ERROR: Expected command line argument for source code file.\nHOWTO: ruby source/cli/cli.rb your_source.em\n"
    exit 1
end


class CLI_Interpreter
    require_relative '../lexer/lexer'
    require_relative '../parser/parser'
    require_relative '../interpreter/interpreter'
    require 'pp'


    def initialize input_file
        @input = File.read input_file
    end


    def output
        tokens = Lexer.new(@input).lex
        ast    = Parser.new(tokens).to_ast
        if ARGV.include? 'parse_only'
            puts "Parsed expressions:\n"
            ast.each do |expr|
                puts PP.pp(expr, '').chomp
            end
            return
        end
        Interpreter.new(ast).interpret!
    end
end


interpreter = CLI_Interpreter.new ARGV[0]
interpreter.output
