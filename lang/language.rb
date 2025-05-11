require 'yaml'
require 'recursive_open_struct'

module Language
	# todo switch to config file over constants
	def self.sort_configuration_file_arrays config_file
		case config_file
			when Array
				config_file.uniq.sort_by do
					-_1.length
				end.freeze
			when Hash
				config_file.transform_values do |v|
					sort_configuration_file_arrays(v)
				end.freeze
			when RecursiveOpenStruct
				RecursiveOpenStruct.new(
				   config_file.to_h.transform_values do |v|
					   sort_configuration_file_arrays(v)
				   end,
				   recurse_over_arrays: true
				).freeze
			else
				config_file
		end
	end

	CONFIG_FILE   = YAML.load_file('./lang/language.yml').freeze
	CONFIG_STRUCT = RecursiveOpenStruct.new(CONFIG_FILE, recurse_over_arrays: true).freeze
	CONFIG        = sort_configuration_file_arrays(CONFIG_STRUCT).freeze

	def self.sort_by_length_desc array
		array.uniq.sort_by { -_1.length }.freeze
	end

	# everything is an identifier, .. including operators. operators are just a kind of identifier
	RESERVED_IDENTIFIERS          = sort_by_length_desc %w(
		if    elsif    elif    else
		while elswhile elwhile
		unless until true false nil
		skip stop   and or
		return
	)
	PREFIX                        = sort_by_length_desc %w(_ __ - + ! ?? ~ > @ # -# >!!! >!! >! ./ ../ .../)
	INFIX                         = sort_by_length_desc %w(. .@ = + - * : / % < > += -= *= |= /= %= &= ^= <<= >>= !== === >== == != <= >= && || & | ^ << >> ** .? .. .< >< >. or and)
	POSTFIX                       = sort_by_length_desc %w(! ? ?? =;)
	RESERVED_OPERATOR_IDENTIFIERS = sort_by_length_desc %w(! ? .. >. .< >< =; .? @ ./ ../ .../ [ { ( , ) } ] _ {} () [] {;} )
	LEGAL_IDENT_SPECIAL_CHARS     = sort_by_length_desc %w(. = + - ~ * @ # $ % ^ & ? / | < > _ : ; ) # these chars may be used as identifiers eg) .:.:, .~~~~~:::, |||, ====.==, whatever~~
	COMMENT_CHAR                  = '`'.freeze
	MULTILINE_COMMENT_CHARS       = '```'.freeze
end
