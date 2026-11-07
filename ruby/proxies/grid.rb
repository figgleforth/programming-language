# Implemented by Claude
#
module Code
	# A grid with one float in each cell. Byte layers (Code::Image) round each change, so a small value that fades or spreads is lost; a Grid keeps it.
	class Grid < Instance
		BYTES_PER_PIXEL = 4 # write_to_image writes only RGBA images

		def initialize name = 'Grid'
			super name
		end

		# A type body reads each member before `Self` makes the cells, so each read allows for none yet.
		def proxy_width
			@grid_width
		end

		def proxy_height
			@grid_height
		end

		def proxy_start width, height, value = 0.0
			raise Code::Invalid_Grid, "A Grid needs a width and a height above 0, but it got #{width} by #{height}." unless width > 0 && height > 0

			@grid_width  = width
			@grid_height = height
			@cells        = ::Array.new width * height, value.to_f
			self
		end

		# --- One cell ---

		def proxy_get x, y
			@cells[cell_index(x, y)]
		end

		def proxy_set x, y, value
			@cells[cell_index(x, y)] = value.to_f
		end

		# @return [::Float] the new value
		def proxy_add x, y, amount
			index = cell_index x, y
			@cells[index] += amount.to_f
		end

		# The whole square around (x, y), row by row, with the center at its middle. A cell outside the Grid is nil, so each index keeps its meaning at the edge.
		# @return [::Array] (radius * 2 + 1) ** 2 values
		def proxy_neighbors x, y, radius = 1
			cell_index x, y
			raise Code::Invalid_Grid, "`radius` must be 0 or more, but it is #{radius}." if radius < 0

			width = @grid_width
			list  = []
			(y - radius..y + radius).each do |row|
				inside_row = row >= 0 && row < @grid_height
				(x - radius..x + radius).each do |column|
					list << (inside_row && column >= 0 && column < width ? @cells[row * width + column] : nil)
				end
			end
			list
		end

		# --- Every cell ---

		def proxy_fill value
			@cells.fill value.to_f
			self
		end

		def proxy_decay factor
			factor = factor.to_f
			@cells.map! { it * factor }
			self
		end

		# Each cell moves toward the mean of its up to four neighbors, and `rate` sets how far.
		def proxy_spread rate
			raise Code::Invalid_Grid, "`rate` must be from 0.0 to 1.0, but it is #{rate}." unless rate >= 0 && rate <= 1

			rate   = rate.to_f
			width  = @grid_width
			height = @grid_height
			old    = @cells
			fresh  = ::Array.new old.length
			index  = 0
			y      = 0
			while y < height
				x = 0
				while x < width
					value = old[index]
					sum   = 0.0
					count = 0
					if x > 0
						sum   += old[index - 1]
						count += 1
					end
					if x < width - 1
						sum   += old[index + 1]
						count += 1
					end
					if y > 0
						sum   += old[index - width]
						count += 1
					end
					if y < height - 1
						sum   += old[index + width]
						count += 1
					end
					fresh[index] = count == 0 ? value : value + rate * (sum / count - value)
					index        += 1
					x            += 1
				end
				y += 1
			end
			@cells = fresh
			self
		end

		def proxy_min
			@cells.min
		end

		def proxy_max
			@cells.max
		end

		def proxy_sum
			@cells.sum
		end

		# --- Images ---

		# @param image [Code::Image] any format; it is read as RGBA
		# @return [Code::Grid] with each byte from 0 to 255 scaled to min .. max
		def proxy_from_image image, channel = 0, min = 0.0, max = 1.0
			check_channel channel
			raw = image.raylib_image
			lib = Code::Raylib.lib
			raise Code::Invalid_Grid, 'The image has no pixels.' unless lib.IsImageValid raw

			colors = lib.LoadImageColors raw
			bytes  = colors.read_bytes raw.width * raw.height * BYTES_PER_PIXEL
			lib.UnloadImageColors colors

			scale          = (max - min) / 255.0
			grid          = Code::Grid.new
			grid.proxy_start raw.width, raw.height
			grid.cells    = (0...raw.width * raw.height).map { min + bytes.getbyte(it * BYTES_PER_PIXEL + channel) * scale }
			grid
		end

		# Writes each value, scaled so that min is 0 and max is 255, and cut off outside that. A nil channel writes r, g and b as gray and leaves alpha.
		# @param image [Code::Image] the same size, in RGBA format
		def proxy_write_to_image image, channel = nil, min = 0.0, max = 1.0
			check_channel channel unless channel.nil?
			raw = image.raylib_image
			lib = Code::Raylib.lib
			raise Code::Invalid_Pixels, "The Grid is #{@grid_width} by #{@grid_height}, but the Image is #{raw.width} by #{raw.height}." unless raw.width == @grid_width && raw.height == @grid_height
			raise Code::Invalid_Pixels, 'write_to_image needs an image in the format :uncompressed_r8g8b8a8.' unless raw.format == lib::PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
			raise Code::Invalid_Grid, "`max` (#{max}) must be above `min` (#{min})." unless max > min

			length = @cells.length * BYTES_PER_PIXEL
			bytes  = raw.data.get_bytes 0, length
			scale  = 255.0 / (max - min)
			min    = min.to_f
			index  = 0
			@cells.each do |value|
				byte = ((value - min) * scale + 0.5).to_i
				byte = 0 if byte < 0
				byte = 255 if byte > 255
				if channel
					bytes.setbyte index + channel, byte
				else
					bytes.setbyte index, byte
					bytes.setbyte index + 1, byte
					bytes.setbyte index + 2, byte
				end
				index += BYTES_PER_PIXEL
			end
			raw.data.put_bytes 0, bytes
			self
		end

		attr_writer :cells

		private

		def cell_index x, y
			unless x >= 0 && x < @grid_width && y >= 0 && y < @grid_height
				raise Code::Invalid_Grid, "The cell (#{x}, #{y}) is not inside the #{@grid_width} by #{@grid_height} Grid."
			end

			y * @grid_width + x
		end

		def check_channel channel
			raise Code::Invalid_Grid, "`channel` must be 0 (r), 1 (g), 2 (b) or 3 (a), but it is #{channel}." unless channel >= 0 && channel <= 3
		end
	end
end
