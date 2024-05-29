require_relative '../lexer/lexer'
require_relative '../parser/parser'

lexer = Lexer.new
# parser = Parser.new
SPACE             = '  '
commands_executed = 1

while true
   # for the label that shows which command number this is
   commands_width    = commands_executed.to_s.length
   command_count     = "#{commands_executed}".rjust commands_width
   commands_executed += 1

   print "#{command_count.rjust(3)})#{SPACE}"
   input = gets.chomp
   break if input == "exit"

   # Print the input back
   repeater = '-'
   repeated = repeater.rjust [commands_width, 1].min.to_i, repeater
   prefix   = repeated.rjust commands_width

   # Execute and print the result of the input
   begin
      lexer.source = input
         # tokens = scanner.string_to_tokens input

      puts "--->#{SPACE}#{lexer.lex}"
      puts
   rescue StandardError => e
      puts "Error: #{e.message}"
   end
end
