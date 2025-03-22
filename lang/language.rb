require 'yaml'
require 'recursive_open_struct'

module Language

	# helper to sort arrays from the config file
	def self.sort_all_arrays obj
		case obj
			when Array
				obj.uniq.sort_by { -_1.length }.freeze
			when Hash
				obj.transform_values { |v| sort_all_arrays(v) }.freeze
			when RecursiveOpenStruct
				RecursiveOpenStruct.new(
				   obj.to_h.transform_values { |v| sort_all_arrays(v) },
				   recurse_over_arrays: true
				).freeze
			else
				obj
		end
	end

	# load the language config from
	CONFIG_FILE   = './lang/language.yml'.freeze
	CONFIG_YAML   = YAML.load_file(CONFIG_FILE).freeze
	CONFIG        = RecursiveOpenStruct.new(CONFIG_YAML, recurse_over_arrays: true).freeze
	SORTED_CONFIG = sort_all_arrays(CONFIG)

	def self.config
		SORTED_CONFIG
	end

	### below is outdated and needs to be removed

	# @param array [Array] The array to sort
	# @return [Array] A copy of the array, sorted by descending length, and frozen.
	def self.sort array
		array.uniq.sort_by { -_1.length }.freeze
	end

	# everything is an identifier, .. including operators. operators are just a kind of identifier

	RESERVED_IDENTIFIERS = sort %w(
		if    elsif    elif    else
		while elswhile elwhile
		unless until true false nil
		skip stop   and or
		return
	)

	PREFIX = sort %w(_ __ - + ! ?? ~ > @ # -# >!!! >!! >! ./ ../ .../)

	INFIX = sort %w(. .@ = + - * : / % < > += -= *= |= /= %= &= ^= <<= >>= !== === >== == != <= >= && || & | ^ << >> ** .? .. .< >< >. or and)

	POSTFIX = %w(! ? ?? =;).sort_by! { -_1.length }

	RESERVED_OPERATOR_IDENTIFIERS = sort %w(! ? .. >. .< >< =; .? @ ./ ../ .../ [ { ( , ) } ] _ {} () [] )

	# these chars may be used as identifiers eg) .:.:, .~~~~~:::, |||, ====.==, whatever~~
	LEGAL_IDENT_SPECIAL_CHARS = sort %w(. = + - ~ * @ # $ % ^ & ? / | < > _ : ; )

	# todo make blacklist for identifiers, everything else is game. everything between two spaces can be an identifier

	COMMENT_CHAR            = '`'.freeze
	MULTILINE_COMMENT_CHARS = '```'.freeze
end

# module Reserved_Tokens
# 	LENGTH_DESC_SORT = ->(str) { -str.length }
#
# 	RESERVED_IDENTIFIERS = %w(
# 		if    elsif    elif    else
# 		while elswhile elwhile else
# 		unless until true false nil
# 		skip stop   and or operator
# 		raise return
# 	).sort_by! &LENGTH_DESC_SORT
#
# 	# RESERVED = %w(>!!! >!! >! =; ≠ .. .< >. >< .? ; .@ @ -@ ./ ../ .../ =).sort_by! { -_1.length }
#
# 	RESERVED_CHARS = %w< [ { ( , ) } ] >.sort_by! { -_1.length } # these cannot be used in custom operator identifiers. They are only for program structure {}, collections [,] and (,)
#
# 	VALID_CHARS   = %w(. = + - ~ * ! @ # $ % ^ & ? / | < > _ : ; ).sort_by! { -_1.length } # examples of valid operators `.:.:`, `.~~~~~:::`, `|||`, `====.==`
# 	LEGAL_SYMBOLS = VALID_CHARS
#
# 	PREFIX = %w(_ __ - + ! ?? ~ > @ # -# >!!! >!! >! ./ ../ .../).sort_by! { -_1.length } # @ _ for scope[@/_]
#
# 	INFIX = %w(. .@ = + - * : / % < > += -= *= |= /= %= &= ^= <<= >>= !== === >== == != <= >= && || & | ^ << >> ** .? .. .< >< >. or and).sort_by! { -_1.length }
#
# 	POSTFIX = %w(! ? ?? =;).sort_by! { -_1.length }
#
# 	# ALL = [RESERVED_IDENTIFIERS, RESERVED, RESERVED_CHARS, VALID_CHARS, PREFIX, INFIX, POSTFIX].inject :+
# end
