require 'minitest/autorun'
require_relative '../lib/ore'
require_relative 'base_test'
require 'net/http'
require 'uri'

class Database_Test < Base_Test
	DATABASE = "#load 'ore/database.ore'"
	RECORD   = "#load 'ore/record.ore'"

	def test_database_instance
		out = Ore.interp <<~ORE
		    #{DATABASE}
			db = Database()
		    sq = Sqlite()
			(db, sq)
		ORE
		assert_instance_of Ore::Database, out.values.first
		assert_instance_of Ore::Database, out.values.last

		assert_nil out.values.first.get 'adapter'
		assert_nil out.values.first.get 'url'
		assert_nil out.values.first.get 'connection'
		assert_nil out.values.last.get 'connection'

		# These are set in Sqlite.new{;}
		refute_nil out.values.last.get 'adapter'
		refute_nil out.values.last.get 'url'
	end

	def test_database_connection_instance
		out = Ore.interp <<~ORE
		    #{DATABASE}
		    db = Sqlite()
		    db.create_connection!()
			db.connection
			db
		ORE
		refute_nil out.get 'connection'
	end

	def test_database_connection_is_cached
		out = Ore.interp <<~ORE
		    #{DATABASE}
		    db = Sqlite()
		    c1 = db.create_connection!()
		    c2 = db.create_connection!()
		    (c1, c2)
		ORE
		assert_equal out.values[0].object_id, out.values[1].object_id
	end

	def test_inferring_record_table_name
		out = Ore.interp <<~ORE
		    #{RECORD}
			r = Record()
			r.table_name

			Thing | Record {}
			t = Thing()
			t.infer_table_name_from_class!()
			(r, t)
		ORE
		assert_nil out.values.first.get 'table_name'
		assert_equal 'things', out.values.last.get('table_name')
	end

	def test_record_requires_database_to_use_query_methods
		assert_raises Ore::Database_Not_Set_For_Record_Instance do
			# bug note: Record.find() raises Missing_Proxy_Method_Declaration so for now calling the static method through an instance
			Ore.interp <<~ORE
			    #{RECORD}
			    Record().find(1)
			ORE
		end

		refute_raises Ore::Database_Not_Set_For_Record_Instance do
			Ore.interp <<~ORE
				#{DATABASE}
			    #{RECORD}
			    db = Sqlite()
			   	db.create_connection!()

			   	Record.database = db.connection
			   	Record.find(1)
			ORE
		end
	end
end
