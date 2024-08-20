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
