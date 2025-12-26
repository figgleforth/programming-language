module Intrinsic_Methods
	def intrinsic_delegate object_name
		define_method "_intrinsic_" do |*args|
			send object_name
		end
	end

	def intrinsic method_name, as: method_name
		define_method "intrinsic_#{as}" do |*args|
			_intrinsic_.send method_name, *args
		end
	end
end
