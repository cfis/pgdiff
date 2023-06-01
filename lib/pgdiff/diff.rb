require 'stringio'

module PgDiff
  class Diff
    def initialize(source_db_spec, target_db_spec, ignore_schemas: [])
      @source_db = PG::Connection.new(source_db_spec)
      @target_db = PG::Connection.new(target_db_spec)
      @ignore_schemas = ignore_schemas
    end

    def run_compare
      @old_database = Database.new(@source_db, ignore_schemas: @ignore_schemas)
      @new_database = Database.new(@target_db, ignore_schemas: @ignore_schemas)

      output = StringIO.new
      Schema.compare(@old_database.schemas, @new_database.schemas, output)
      Extension.compare(@old_database.extensions, @new_database.extensions, output)
      Domain.compare(@old_database.domains, @new_database.domains, output)
      Sequence.compare(@old_database.sequences, @new_database.sequences, output)
      Table.compare(@old_database.tables, @new_database.tables, output)
      Trigger.compare(@old_database.triggers, @new_database.triggers, output)
      View.compare(@old_database.views, @new_database.views, output)
      Rule.compare(@old_database.rules, @new_database.rules, output)
      Function.compare(@old_database.functions, @new_database.functions, output)

      output.string
    end

    def add_script(section, statement)
      @script[section] << statement
    end

    def diff_attributes(old_table, new_table)
      dropped = []
      added   = []
      changed = []

      order = []
      old_table.attributes.keys.each do |attname|
        if new_table.has_attribute?(attname)
          changed << attname if old_table.attributes[attname] != new_table.attributes[attname]
        else
          dropped << attname
        end
      end

      old_table.attributes.keys.each do |attname|
        if new_table.has_attribute?(attname)
          old_index = old_table.attribute_index(attname)
          new_index = new_table.attribute_index(attname)
          order << attname if old_index != new_index
        end
      end
      new_table.attributes.keys.each do |attname|
        added << attname unless old_table.has_attribute?(attname)
      end
      add_script(:tables_change ,  "--  [#{old_table.name}] dropped attributes") unless dropped.empty?
      dropped.each do |attname|
        add_script(:tables_change ,  "ALTER TABLE #{old_table.name} DROP COLUMN #{attname} CASCADE;")
      end
      add_script(:tables_change ,  "--  [#{old_table.name}] added attributes") unless added.empty?
      added.each do |attname|
        add_script(:tables_change ,  "    ALTER TABLE #{old_table.name} ADD COLUMN #{new_table.attributes[attname].definition};")
      end
      add_script(:tables_change ,  "--  [#{old_table.name}] changed attributes") unless changed.empty?
      changed.each do |attname|
        old_att = old_table.attributes[attname]
        new_att = new_table.attributes[attname]
        add_script(:tables_change ,  "--   attribute: #{attname}")
        add_script(:tables_change ,  "--     OLD : #{old_att.definition}")
        add_script(:tables_change ,  "--     NEW : #{new_att.definition}")
        if old_att.type_def != new_att.type_def
          add_script(:tables_change ,  "      ALTER TABLE #{old_table.name} ALTER COLUMN #{attname} TYPE #{new_att.type_def};")
        end
        if old_att.default != new_att.default
          if new_att.default.nil?
            add_script(:tables_change ,  "       ALTER TABLE #{old_table.name} ALTER COLUMN #{attname} DROP DEFAULT;")
          else
            add_script(:tables_change ,  "       ALTER TABLE #{old_table.name} ALTER COLUMN #{attname} SET DEFAULT #{new_att.default};")
          end
        end
        if old_att.notnull != new_att.notnull
          add_script(:tables_change ,  "       ALTER TABLE #{old_table.name} ALTER COLUMN #{attname} #{new_att.notnull ? 'SET' : 'DROP'} NOT NULL;")
        end
      end

      add_script(:tables_change ,   "--  [#{old_table.name}] attribute order changed") unless order.empty?
      order.each do |attname|
        add_script(:tables_change , "--    #{attname}.  Old index: #{old_table.attribute_index(attname)}, New index: #{new_table.attribute_index(attname)}")
      end
    end

    def diff_constraints(old_table, new_table)
      dropped = []
      added   = []
      changed = []

      old_table.constraints.keys.each do |conname|
        if new_table.has_constraint?(conname)
          if old_table.constraints[conname] != new_table.constraints[conname]
            changed << conname
          end
        else
          dropped << conname
        end
      end

      new_table.constraints.keys.each do |conname|
        added << conname unless old_table.has_constraint?(conname)
      end

      dropped.each do |name|
        add_script(:constraints_drop ,  "ALTER TABLE #{old_table.name} DROP CONSTRAINT #{name};")
      end

      added.each do |name|
        add_cnstr(old_table.name,  name, new_table.constraints[name])
      end

      changed.each do |name|
        add_script(:constraints_change,
                   "-- Previous: #{old_table.constraints[name]}\n" +
                   "ALTER TABLE #{old_table.name} DROP CONSTRAINT #{name};\n" +
                   "ALTER TABLE #{new_table.name} ADD CONSTRAINT #{name} #{new_table.constraints[name]};\n")
      end
    end

    def add_cnstr(tablename, cnstrname, cnstrdef)
      c_string = "ALTER TABLE #{tablename} ADD CONSTRAINT #{cnstrname} #{cnstrdef} ;"
      case cnstrdef
        when /^CHECK /   then @c_check  << c_string
        when /^PRIMARY / then @c_primary << c_string
        when /^FOREIGN / then @c_foreign << c_string
        when /^UNIQUE /  then @c_unique  << c_string
      end
    end

    def diff_indexes(old_table, new_table)
      dropped = []
      added   = []

      old_table.indexes.keys.each do |name|
        if new_table.has_index?(name)
          if old_table.indexes[name] != new_table.indexes[name]
            dropped << name
            added << name
          end
        else
          dropped << name
        end
      end
      new_table.indexes.keys.each do |name|
        added << name unless old_table.has_index?(name)
      end

      dropped.each do |name|
        add_script(:indices_drop ,  "DROP INDEX #{name};")
      end
      added.each do |name|
        add_script(:indices_create ,  (new_table.indexes[name] + ";")) if new_table.indexes[name]
      end
    end
  end
end
