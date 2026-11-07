# Implemented by Claude
#
module Code
	# A loaded texture: a thin wrapper around the FFI struct that raylib returns. Code::Raylib wraps it on the way out and unwraps it on the way back in.
	class Texture < Instance
		# @return ::Raylib::Texture
		attr_accessor :raylib_texture

		def initialize name = 'Texture'
			super name
		end

		# A type body reads each member before `Self` loads the texture, so each read allows for no struct yet.
		def proxy_id = @raylib_texture&.id
		def proxy_width = @raylib_texture&.width
		def proxy_height = @raylib_texture&.height
		def proxy_mipmaps = @raylib_texture&.mipmaps
		def proxy_format = @raylib_texture&.format

		def proxy_load path
			@raylib_texture = Code::Raylib.valid_texture Code::Raylib.lib.LoadTexture(path), path
			self
		end
	end
end
