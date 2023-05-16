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
      compare_triggers_drop
      compare_rules_drop
      compare_views_drop
      compare_tables
      compare_views_create
      compare_functions
      compare_rules_create
      compare_triggers_create
      compare_table_constraints
    end

    def add_script(section, statement)
      @script[section] << statement
    end

    def compare_schemas
      @old_database.schemas.keys.each do |name|
        add_script(:schemas_drop ,  "DROP SCHEMA #{name};") unless @new_database.schemas.has_key?(name)
      end
      @new_database.schemas.keys.each do |name|
        add_script(:schemas_create ,  "CREATE SCHEMA #{name};") unless @old_database.schemas.has_key?(name)
      end
    end

    def compare_extensions
      @old_database.extensions.each do |extension|
        add_script(:extensions_drop ,  "DROP EXTENSION #{extension.schema}.#{extension.name}; -- Version is #{extension.version}") unless @new_database.extensions.include?(extension)
      end
      @new_database.extensions.each do |extension|
        add_script(:extensions_create ,  "CREATE EXTENSION #{extension.name} WITH SCHEMA #{extension.schema} VERSION #{extension.version};") unless @old_database.extensions.include?(extension)
      end
    end

    def compare_domains
      @old_database.domains.keys.each do |name|
        add_script(:domains_drop ,  "DROP DOMAIN #{name} CASCADE;") unless @new_database.domains.has_key?(name)
      end
      @new_database.domains.each do |name, df|
        add_script(:domains_create ,  "CREATE DOMAIN #{name} AS #{df};") unless @old_database.domains.has_key?(name)
        old_domain = @old_database.domains[name]
        if old_domain && old_domain != df
           add_script(:domains_drop, "DROP DOMAIN #{name} CASCADE;")
           add_script(:domains_create,  "-- [changed domain] :")
           add_script(:domains_create,  "-- OLD: #{old_domain}")
           add_script(:domains_create,  "CREATE DOMAIN #{name} AS #{df};")
        end
      end
    end

    def compare_sequences
      @old_database.sequences.keys.each do |name|
        add_script(:sequences_drop ,  "DROP SEQUENCE #{name} CASCADE;") unless @new_database.sequences.has_key?(name)
      end
      @new_database.sequences.keys.each do |name|
        add_script(:sequences_create ,  "CREATE SEQUENCE #{name};") unless @old_database.sequences.has_key?(name)
      end
    end

    def compare_functions
      @old_database.functions.keys.each do |name|
        add_script(:functions_drop ,  "DROP FUNCTION #{name} CASCADE;") unless @new_database.functions.has_key?(name)
      end
      @new_database.functions.each do |name, func|
        add_script(:functions_create ,   func.definition) unless @old_database.functions.has_key?(name)
        old_function = @old_database.functions[name]
        if old_function && old_function.definition != func.definition
          add_script(:functions_create , '-- [changed function] :')
          add_script(:functions_create , '-- OLD :')
          add_script(:functions_create ,  old_function.definition.gsub(/^/, "-->  ") )
          add_script(:functions_create ,   func.definition)
        end
      end
    end

    def compare_rules_drop
      @old_database.rules.each do |name, rule|
        add_script(:rules_drop ,  "DROP RULE #{rule.name} ON #{rule.table_name} CASCADE;") unless @new_database.rules.has_key?(name)
      end
    end

    def compare_rules_create
      @new_database.rules.each do |name, rule|
        add_script(:rules_create ,   rule.definition) unless @old_database.rules.has_key?(name)
        old_rule = @old_database.rules[name]
        if old_rule && old_rule != rule
          add_script(:rules_drop ,  "DROP RULE #{rule.name} ON #{rule.table_name} CASCADE;")
          add_script(:rules_create ,  "-- [changed rule] :")
          add_script(:rules_create ,  "-- OLD: #{old_rule.definition}")
          add_script(:rules_create ,   rule.definition )
        end
      end
    end

    def compare_triggers_drop
      @old_database.triggers.each do |name, trigger|
        add_script(:triggers_drop ,  "DROP trigger #{trigger.name} ON #{trigger.table_name} CASCADE;") unless @new_database.triggers.has_key?(name)
      end
    end

    def compare_triggers_create
      @new_database.triggers.each do |name, trigger|
        add_script(:triggers_create ,   trigger.definition) unless @old_database.triggers.has_key?(name)
        old_trigger = @old_database.triggers[name]
        if old_trigger && old_trigger != trigger
          add_script(:triggers_drop ,  "DROP trigger #{trigger.name} ON #{trigger.table_name} CASCADE;")
          add_script(:triggers_create ,  "-- [changed trigger] :")
          add_script(:triggers_create ,  "-- OLD #{old_trigger.definition}")
          add_script(:triggers_create ,   trigger.definition)
        end
      end
    end

    def compare_views_drop
      @old_database.views.keys.each do |name|
        add_script(:views_drop ,  "DROP VIEW #{name};") unless @new_database.views.has_key?(name)
      end
    end

    def compare_views_create
      @new_database.views.each do |name, df|
        add_script(:views_create ,   df.definition) unless @old_database.views.has_key?(name)
        old_view = @old_database.views[name]
        if old_view && df.definition != old_view.definition
          add_script(:views_drop ,  "DROP VIEW #{name};")
          add_script(:views_create ,  "-- [changed view] :")
          add_script(:views_create ,  "-- #{old_view.definition.gsub(/\n/, ' ')}")
          add_script(:views_create ,  df.definition)
        end
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
