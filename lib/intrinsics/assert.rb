require_relative '../air'

module Air
	def self.assert condition = false, message = nil
		message ||= "TODO Assert triggered message"
		raise message unless condition
	end

	class Assert < Func; end
end
