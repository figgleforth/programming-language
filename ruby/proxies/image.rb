# Implemented by Claude
#
module Code
	# An image in CPU memory: a thin wrapper around the FFI struct that raylib returns. A function that changes an image (`ImageResize`) can replace the struct's data, so Code::Raylib passes a pointer to this one struct each time.
	class Image < Instance
		# @return ::Raylib::Image
		attr_accessor :raylib_image

		def initialize name = 'Image'
			super name
		end

		# A type body reads each member before `Self` loads the image, so each read allows for no struct yet.
		def proxy_width = @raylib_image&.width
		def proxy_height = @raylib_image&.height
		def proxy_mipmaps = @raylib_image&.mipmaps
		def proxy_format = @raylib_image&.format

		def proxy_load path
			@raylib_image = Code::Raylib.valid_image Code::Raylib.lib.LoadImage(path), path
			self
		end
	end
end
