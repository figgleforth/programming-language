require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Composition_Test < Base_Test
	def test_union_viewer_has_read_permissions
		out = Code.interp "
		@load 'examples/compositions.code'
		v := Viewer()
		<v.can_view, v.can_list, v.user_type>"

		assert_equal [true, true, 'viewer'], out.values
	end

	def test_union_viewer_does_not_have_write_permissions
		assert_raises Code::Undeclared_Identifier do
			Code.interp "
			@load 'examples/compositions.code'
			v := Viewer()
			v.can_create"
		end
	end

	def test_union_editor_has_read_and_write_permissions
		out = Code.interp "
		@load 'examples/compositions.code'
		e := Editor()
		<e.can_view, e.can_list, e.can_create, e.can_update, e.can_delete, e.user_type>"

		assert_equal [true, true, true, true, true, 'editor'], out.values
	end

	def test_union_administrator_has_all_permissions
		out = Code.interp "
		@load 'examples/compositions.code'
		a := Administrator()
		<a.can_view, a.can_create, a.can_manage_users, a.user_type>"

		assert_equal [true, true, true, 'admin'], out.values
	end

	def test_removal_limited_editor_cannot_delete
		refute_raises Code::Undeclared_Identifier do
			out = Code.interp "
			@load 'examples/compositions.code'
			l := Limited_Editor()
			<l.can_create, l.can_update, l.user_type>"
			assert_equal [true, true, 'limited_editor'], out.values
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "
			@load 'examples/compositions.code'
			l := Limited_Editor()
			l.can_delete"
		end
	end

	def test_removal_read_only_admin_cannot_write
		refute_raises Code::Undeclared_Identifier do
			out = Code.interp "
			@load 'examples/compositions.code'
			r := Read_Only_Admin()
			<r.can_manage_users, r.can_view, r.user_type>"
			assert_equal [true, true, 'read_only_admin'], out.values
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "
			@load 'examples/compositions.code'
			r := Read_Only_Admin()
			r.can_create"
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "
			@load 'examples/compositions.code'
			r := Read_Only_Admin()
			r.can_delete"
		end
	end

	def test_vehicle_sedan_has_basic_features
		out = Code.interp "
		@load 'examples/compositions.code'
		s := Sedan()
		<s.has_engine, s.has_wheels, s.model>"

		assert_equal [true, true, 'sedan'], out.values
	end

	def test_vehicle_luxury_sedan_has_luxury_features
		out = Code.interp "
		@load 'examples/compositions.code'
		l := Luxury_Sedan()
		<l.has_engine, l.has_leather_seats, l.has_sunroof, l.model>"

		assert_equal [true, true, true, 'luxury_sedan'], out.values
	end

	def test_vehicle_electric_car_has_no_traditional_engine
		out = Code.interp "
		@load 'examples/compositions.code'
		e := Electric_Car()
		<e.has_wheels, e.has_battery, e.has_engine, e.model>"

		assert_equal [true, true, false, 'electric'], out.values
	end

	def test_vehicle_luxury_electric_combines_features
		out = Code.interp "
		@load 'examples/compositions.code'
		l := Luxury_Electric()
		<l.has_wheels, l.has_leather_seats, l.has_battery, l.has_engine, l.model>"

		assert_equal [true, true, true, false, 'luxury_electric'], out.values
	end

	def test_api_public_user_response_has_only_shared_members
		refute_raises Code::Undeclared_Identifier do
			out = Code.interp "
			@load 'examples/compositions.code'
			p := Public_User_Response()
			<p.status, p.user_id, p.username, p.response_type>"
			assert_equal [200, 0, '', 'public'], out.values
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "
			@load 'examples/compositions.code'
			p := Public_User_Response()
			p.email"
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "
			@load 'examples/compositions.code'
			p := Public_User_Response()
			p.avatar_url"
		end
	end

	def test_api_private_user_response_has_all_members
		out = Code.interp "
		@load 'examples/compositions.code'
		p := Private_User_Response()
		<p.status, p.user_id, p.username, p.email, p.response_type>"

		assert_equal [200, 0, '', '', 'private'], out.values
	end

	def test_api_limited_user_response_removes_private_members
		refute_raises Code::Undeclared_Identifier do
			out = Code.interp "
			@load 'examples/compositions.code'
			l := Limited_User_Response()
			<l.user_id, l.username, l.response_type>"
			assert_equal [0, '', 'limited'], out.values
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "
			@load 'examples/compositions.code'
			l := Limited_User_Response()
			l.email"
		end
	end

	# A composition in a value builds an anonymous type (#compose_type_values), not a change to whatever scope is on top of the stack.
	def test_a_composition_in_a_value_builds_an_anonymous_type
		out = Code.interp "
		Base {}
		Compo { a := 1 }
		x := Base + Compo
		y := x()
		<y.a, (y =>= Compo), (y =>= Base)>"
		assert_equal [1, true, true], out.values
	end

	def test_a_composition_in_a_value_can_remove_members
		out = Code.interp "
		This { a := 1, shared := 'this' }
		That { b := 2, shared := 'that' }
		w := (This + That - That)()
		<w.a, w.?b, w.?shared>"
		assert_equal [1, nil, nil], out.values
	end

	# Declared as a member inside a type body, it scopes to that member -- Compo does not splat into the enclosing Type's own declarations the way `Self += Compo` would.
	def test_a_composition_assigned_inside_a_type_body_does_not_leak_into_the_enclosing_type
		assert_raises Code::Undeclared_Identifier do
			Code.interp "
			Base {}
			Compo { a := 99 }
			Type { x := Base + Compo }
			t := Type()
			t.a"
		end
	end

	def test_a_composition_assigned_inside_a_type_body_is_reachable_through_its_member
		out = Code.interp "
		Base {}
		Compo { a := 99 }
		Type { x := Base + Compo }
		t := Type()
		i := t.x()
		i.a"
		assert_equal 99, out
	end

	def test_self_composition_outside_a_type_raises
		assert_raises Code::Composition_Outside_Type_Declaration do
			Code.interp "
			Compo { a := 1 }
			Self += Compo"
		end
	end

	def test_self_plus_equals_in_a_type_body_composes_like_a_head
		out = Code.interp "
		Number {}
		Float { Self += Number }
		Float =>= Number"
		assert_equal true, out
	end

	# A body runs on the type when it is declared, then again on each instance. A condition can be true for one instance only, and then only that instance has the members and the type, as with Ruby's `extend`.
	def test_self_plus_equals_inside_an_if_can_compose_one_instance_only
		out = Code.interp "
		Logging {
			log (;
				'logged'
			)
		}
		n := 0
		Duck {
			n += 1
			if n == 2
				Self += Logging
			end
		}
		d := Duck()
		e := Duck()
		<(d =>= Logging), (e =>= Logging), (Duck =>= Logging), d.log(), e.?log>"
		assert_equal [true, false, false, 'logged', nil], out.values
	end

	# An instance that removes a type loses its members too, so they do not resolve through its own type either.
	def test_self_minus_equals_inside_an_if_can_remove_a_type_from_one_instance_only
		out = Code.interp "
		Flying {
			wings := 2
			fly (;
				'flew'
			)
		}
		n := 0
		Bird + Flying {
			n += 1
			if n == 2
				Self -= Flying
			end
		}
		a := Bird()
		b := Bird()
		<(a =>= Flying), (b =>= Flying), (Bird =>= Flying), a.?wings, a.?fly, b.wings, b.fly()>"
		assert_equal [false, true, true, nil, nil, 2, 'flew'], out.values
	end

	# `-=` then `+=` swaps one type for another, and a later `+=` brings the removed members back.
	def test_self_minus_equals_then_plus_equals_swaps_a_type_in_a_method
		out = Code.interp "
		Flying {
			fly (;
				'flew'
			)
		}
		Robot {
			beep (;
				'beep'
			)
		}
		Bird + Flying {
			swap (;
				self -= Flying
				self += Robot
			)
			relearn (;
				self += Flying
			)
		}
		b := Bird()
		b.swap()
		swapped := <(b =>= Flying), (b =>= Robot), b.?fly, b.beep()>
		b.relearn()
		<swapped, (b =>= Flying), b.fly(), Bird().fly()>"
		swapped, *after = out.values
		assert_equal [false, true, nil, 'beep'], swapped.values
		assert_equal [true, 'flew', 'flew'], after
	end

	def test_a_removed_member_cannot_be_written
		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp "
			Flying { wings := 2 }
			Bird + Flying {
				drop (;
					self -= Flying
				)
			}
			b := Bird()
			b.drop()
			b.wings = 5"
		end
	end

	# In a method, `self += X` changes only this instance.
	def test_self_plus_equals_in_a_method_composes_only_this_instance
		out = Code.interp "
		Flying {
			fly (;
				'flew'
			)
		}
		Penguin {
			upgrade (;
				self += Flying
			)
		}
		p := Penguin()
		q := Penguin()
		q.upgrade()
		<(q =>= Flying), (p =>= Flying), (Penguin =>= Flying), q.fly(), p.?fly>"
		assert_equal [true, false, false, 'flew', nil], out.values
	end

	# In a method, `Self += X` changes the type. The instances built after it get the change, and the ones built before keep what they had.
	def test_capital_self_plus_equals_in_a_method_reaches_only_later_instances
		out = Code.interp "
		Logging {
			log (;
				'logged'
			)
		}
		Penguin {
			everyone (;
				Self += Logging
			)
		}
		p := Penguin()
		p.everyone()
		later := Penguin()
		<(Penguin =>= Logging), (p =>= Logging), p.?log, (later =>= Logging), later.log()>"
		assert_equal [true, false, nil, true, 'logged'], out.values
	end

	def test_capital_self_minus_equals_in_a_method_reaches_only_later_instances
		out = Code.interp "
		Flying {
			fly (;
				'flew'
			)
		}
		Bird + Flying {
			ground (;
				Self -= Flying
			)
		}
		early := Bird()
		early.ground()
		later := Bird()
		<(Bird =>= Flying), (early =>= Flying), early.fly(), (later =>= Flying), later.?fly>"
		assert_equal [false, true, 'flew', false, nil], out.values
	end

	# The type records what ran, with its value: a `Self +=` behind a false condition records nothing, and a local operand still replays after the method returns.
	def test_a_type_change_in_a_method_replays_what_ran
		out = Code.interp "
		Swimming {
			swim (;
				'swam'
			)
		}
		Logging {
			log (;
				'logged'
			)
		}
		Bird {
			maybe ( yes;
				if yes
					Self += Swimming
				end
			)
			add ( type;
				chosen := type
				Self += chosen
			)
		}
		b := Bird()
		b.maybe(false)
		b.add(Logging)
		later := Bird()
		<(later =>= Swimming), later.?swim, (later =>= Logging), later.log()>"
		assert_equal [false, nil, true, 'logged'], out.values
	end

	# A later declaration still reaches an instance built before it, as a forward declaration needs. Only a change a method makes is held back.
	def test_a_later_declaration_still_reaches_an_earlier_instance
		out = Code.interp "
		p := This()
		This := That {}
		That {
			greet (;
				'hi'
			)
		}
		p.greet()"
		assert_equal 'hi', out
	end

	def test_lowercase_self_plus_equals_in_a_type_body_raises
		assert_raises Code::Cannot_Use_Instance_Scope_Operator_Outside_Instance do
			Code.interp "
			Compo { a := 1 }
			Type { self += Compo }"
		end
	end

	# A composed-in Array/Dictionary/Instance-valued member used to be copied by *reference* -- since
	# composition re-runs for every instance built (not just once, at the composing type's own
	# declaration), every instance of every composing type ended up sharing the exact same mutable
	# object. #dup_composed_value fixes this by duping a mutable value when it's copied in.

	def test_composed_array_member_is_independent_per_instance
		out = Code.interp "
		Has_Items { items := [] }
		A + Has_Items {}
		a := A()
		b := A()
		a.items.push('a-item')
		b.items.push('b-item')
		<a.items, b.items>"
		assert_equal [['a-item'], ['b-item']], out.values.map(&:values)
	end

	def test_composed_dictionary_member_is_independent_per_instance
		out = Code.interp "
		Has_Store { store := {} }
		A + Has_Store {}
		a := A()
		b := A()
		a.store[:x] = 1
		b.store[:x] = 2
		<a.store[:x], b.store[:x]>"
		assert_equal [1, 2], out.values
	end

	# Method sharing via composition (the whole point of `|`) must be unaffected -- Code::Func isn't a
	# Code::Instance, so #dup_composed_value leaves it untouched.
	def test_composed_method_is_still_shared_and_callable
		out = Code.interp "
		Greeter { greet ( name; \"Hello, `name`!\" ) }
		My_Type + Greeter {}
		My_Type().greet('World')"
		assert_equal 'Hello, World!', out
	end

	# An instance shares its type's `types` Set until it composes something of its own. This runs the composition directly, with no `Self +=`, to check the Set itself.
	def test_composing_into_one_instance_leaves_the_type_and_other_instances_alone
		interpreter = Code::Interpreter.new
		interpreter.run "Logging {}\nSwimming {}\nDuck + Swimming {}\nWith_Logging + Logging {}\nWithout_Swimming - Swimming {}\nd := Duck()\ne := Duck()"
		duck, d, e = %w(Duck d e).map { interpreter.global[it] }
		add_logging, remove_swimming = %w(With_Logging Without_Swimming).map { interpreter.global[it].expressions.first }

		interpreter.push_then_pop(d) { interpreter.interp_composition add_logging }
		assert_includes d.types, 'Logging'
		refute_includes duck.types, 'Logging'
		refute_includes e.types, 'Logging'

		interpreter.push_then_pop(e) { interpreter.interp_composition remove_swimming }
		refute_includes e.types, 'Swimming'
		assert_includes duck.types, 'Swimming'
		assert_includes d.types, 'Swimming'
	end

	# `Self` in an annotation is the type that uses it. A method that `Node` gets from `Linked` takes and returns a `Node`, and on a plain `Linked` it takes a `Linked`.
	def test_self_in_a_composed_annotation_is_the_type_that_uses_it
		setup = "
		Linked {
			link ( other: Self -> Self;
				other
			)
		}
		Node + Linked {}
		"
		assert_equal 'Node', Code.interp("#{setup}\nNode().link(Node()).@name")
		assert_equal 'Linked', Code.interp("#{setup}\nLinked().link(Linked()).@name")
		error = assert_raises(Code::Type_Contract_Violation) { Code.interp "#{setup}\nNode().link(Linked())" }
		assert_equal %w(Node Linked), [error.contract, error.actual]
	end
end
