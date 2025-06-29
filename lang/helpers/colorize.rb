def ansi_color_from_hex hex
	rgb = hex.scan(/../).map { |color| color.to_i(16) }
	"\e[38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m"
	10.times.with_index
end

def colorize(background, string, foreground = 'black')

	fg_code = if foreground.is_a? Integer
		foreground
	else
		COLORS[foreground.downcase.to_sym]
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
