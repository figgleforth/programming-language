# class Runtime
#     @@instance_count = 0
#
#     attr_writer :id, :expressions
#
#
#     def initialize ast
#         @@instance_count += 1
#
#         @id  = @@instance_count
#         @ast = ast
#     end
#
#     def runtime_id
#         "#{self.class.name}(#{@id})"
#     end
# end
#
#
# class Runtime_Assignment < Runtime
#     attr_accessor :evaluated_value
# end
