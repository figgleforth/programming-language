require_relative 'tokenizer'

space = '  '
scanner = Tokenizer.new
command = 1

while true
  # for the label that shows which command number this is
  commands_width = command.to_s.length
  command_count = "#{command}".rjust commands_width
  command += 1

  print "#{command_count.rjust(3)})#{space}"
  input = gets.chomp
  break if input == "exit"

  # Print the input back
  repeater = '-'
  repeated = repeater.rjust [commands_width, 1].min, repeater
  prefix = repeated.rjust commands_width

  # Execute and print the result of the input
  begin
    tokens = scanner.string_to_tokens input

    puts "--->#{space}#{scanner.tokens.inspect}"
    puts
  rescue StandardError => e
    puts "Error: #{e.message}"
  end
end
