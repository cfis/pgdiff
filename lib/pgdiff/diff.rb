require 'stringio'

module PgDiff
  class Diff
    def initialize(output, source_db_spec, target_db_spec, ignore_schemas: [])
      @output = output
      @source_db = PG::Connection.new(source_db_spec)
      @target_db = PG::Connection.new(target_db_spec)
      @ignore_schemas = ignore_schemas
    end

    def run_compare
      @old_database = Database.new(@source_db, ignore_schemas: @ignore_schemas)
      @new_database = Database.new(@target_db, ignore_schemas: @ignore_schemas)

      Schema.compare(@old_database.schemas, @new_database.schemas, @output)
      Extension.compare(@old_database.extensions, @new_database.extensions, @output)
      Domain.compare(@old_database.domains, @new_database.domains, @output)
      Sequence.compare(@old_database.sequences, @new_database.sequences, @output)
      Table.compare(@old_database.tables, @new_database.tables, @output)
      Trigger.compare(@old_database.triggers, @new_database.triggers, @output)
      View.compare(@old_database.views, @new_database.views, @output)
      Rule.compare(@old_database.rules, @new_database.rules, @output)
      Function.compare(@old_database.functions, @new_database.functions, @output)
    end
  end
end
