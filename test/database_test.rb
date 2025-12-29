require 'minitest/autorun'
require_relative '../lib/ore'
require_relative 'base_test'
require 'net/http'
require 'uri'

class Database_Test < Base_Test
	DATABASE = "#load 'ore/database.ore'"

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
end
