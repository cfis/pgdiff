require 'stringio'

module PgDiff
  class Diff
    def initialize(source_db_spec, target_db_spec, ignore_schemas: [])
      @source_db = PG::Connection.new(source_db_spec)
      @target_db = PG::Connection.new(target_db_spec)
      @ignore_schemas = ignore_schemas

      @sections = [
        :domains_drop,
        :domains_create,
        :schemas_drop,
        :schemas_create,
        :extensions_create,
        :extensions_alter,
        :extensions_drop,
        :tables_drop,
        :tables_change,
        :tables_create,
        :sequences_drop,
        :sequences_create,
        :views_drop,
        :views_create,
        :constraints_drop,
        :constraints_change,
        :constraints_create,
        :indices_drop,
        :indices_create,
        :functions_drop,
        :functions_create ,
        :triggers_drop,
        :triggers_create ,
        :rules_drop,
        :rules_create
      ]
      @script = {}
      @sections.each {|s| @script[s] = []}
    end

    def run_compare
      @old_database = Database.new(@source_db, ignore_schemas: @ignore_schemas)
      @new_database = Database.new(@target_db, ignore_schemas: @ignore_schemas)
      compare_schemas
      compare_extensions
      compare_domains
      compare_sequences
      compare_triggers
      compare_rules
      compare_views
      compare_tables
      compare_functions
      compare_table_constraints
    end

    def add_script(section, statement)
      @script[section] << statement
    end

    def compare_schemas
      @old_database.schemas.difference(@new_database.schemas).each do |schema|
        add_script(:schemas_drop, schema.drop_statement)
      end

      @new_database.schemas.difference(@old_database.schemas).each do |schema|
        add_script(:schemas_create, schema.create_statement)
      end
    end

    def compare_extensions
      @old_database.extensions.intersection(@new_database.extensions).each do |old_extension|
        new_extension = @new_database.extensions.find do |an_extension|
          old_extension.qualified_name == an_extension.qualified_name
        end
        if old_extension.version < new_extension.version
          # Upgrade
          add_script(:extensions_alter, new_extension.alter_statement)
        elsif old_extension.version > new_extension.version
          # Downgrade
          add_script(:extensions_drop, old_extension.drop_statement)
          add_script(:extensions_create, new_extension.create_statement)
        end
      end

      @old_database.extensions.difference(@new_database.extensions).each do |extension|
        add_script(:extensions_drop, extension.drop_statement)
      end

      @new_database.extensions.difference(@old_database.extensions).each do |extension|
        add_script(:extensions_create, extension.create_statement)
      end
    end

    def compare_domains
      @old_database.domains.difference(@new_database.domains).each do |domain|
        add_script(:domains_drop, domain.drop_statement)
      end

      @new_database.domains.difference(@old_database.domains).each do |domain|
        add_script(:domains_create, domain.create_statement)
      end
    end

    def compare_sequences
      @old_database.sequences.difference(@new_database.sequences).each do |sequence|
        add_script(:schemas_drop, sequence.drop_statement)
      end

      @new_database.sequences.difference(@old_database.sequences).each do |sequence|
        add_script(:schemas_create, sequence.create_statement)
      end
    end

    def compare_functions
      @old_database.functions.difference(@new_database.functions).each do |function|
        add_script(:functions_drop, function.drop_statement)
      end

      @new_database.functions.difference(@old_database.functions).each do |function|
        add_script(:functions_create, function.create_statement)
      end
    end

    def compare_rules
      @old_database.rules.difference(@new_database.rules).each do |rule|
        add_script(:rules_drop, rule.drop_statement)
      end

      @new_database.rules.difference(@old_database.rules).each do |rule|
        add_script(:rules_create, rule.create_statement)
      end
    end

    def compare_triggers
      @old_database.triggers.difference(@new_database.triggers).each do |trigger|
        add_script(:triggers_drop, trigger.drop_statement)
      end

      @new_database.triggers.difference(@old_database.triggers).each do |trigger|
        add_script(:triggers_create, trigger.create_statement)
      end
    end

    def compare_views
      @old_database.views.difference(@new_database.views).each do |view|
        add_script(:views_drop, view.drop_statement)
      end

      @new_database.views.difference(@old_database.views).each do |view|
        add_script(:views_create, view.create_statement)
      end
    end

    def compare_tables
      @old_database.tables.each do |name, table|
        add_script(:tables_drop, "DROP TABLE #{name} CASCADE;") unless @new_database.tables.has_key?(name)
      end
      @to_compare = []
      @new_database.tables.each do |name, table|
        unless @old_database.tables.has_key?(name)
          add_script(:tables_create ,  table.table_creation)
          add_script(:indices_create ,  table.index_creation) unless table.indexes.empty?
          @to_compare << name
        else
          diff_attributes(@old_database.tables[name], table)
          diff_indexes(@old_database.tables[name], table)
          @to_compare << name
        end
      end
    end

    def compare_table_constraints
      @c_check = []
      @c_primary = []
      @c_unique = []
      @c_foreign = []
      @to_compare.each do |name|
        if @old_database.tables[name]
          diff_constraints(@old_database.tables[name], @new_database.tables[name])
        else
          @new_database.tables[name].constraints.each do |cname, cdef|
            add_cnstr(name,  cname, cdef)
          end
        end
      end
      @script[:constraints_create] += @c_check
      @script[:constraints_create] += @c_primary
      @script[:constraints_create] += @c_unique
      @script[:constraints_create] += @c_foreign
    end

    def output
      out = StringIO.new
      @sections.each do |sect|
        unless @script[sect].empty?
           out << "-- **** #{sect.to_s.upcase} ****" << "\n"
           @script[sect].each do |script|
             out << script << "\n"
           end
           out << "\n"
        end
      end
      out.string
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
