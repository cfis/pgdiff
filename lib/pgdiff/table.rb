require 'diff/lcs'
require 'diff/lcs/hunk'

module PgDiff
  class Table
    attr_accessor :oid, :schema, :name, :attributes, :constraints, :indexes

    def self.compare(sources, targets, output)
      drops = []
      creates = []
      updates = []

      source_hash = sources.each_with_object(Hash.new) do |table, hash|
        hash[table.qualified_name] = table
      end

      target_hash = targets.each_with_object(Hash.new) do |table, hash|
        hash[table.qualified_name] = table
      end

      source_hash.each do |key, source|
        target = target_hash[key]
        case
          when target.nil?
            drops << source
          when !source.eql?(target)
            updates << [source, target]
        end
      end

      target_hash.each do |key, target|
        source = source_hash[key]
        if source.nil?
          creates << target
        end
      end

      drops.each do |table|
        output << table.drop_statement << "\n"
      end

      creates.each do |table|
        output << table.create_statement << "\n"
      end

      updates.each do |source, target|
        output << "/* Table " << source.qualified_name << " has changed attributes" << "\n"
        diffs = ::Diff::LCS.diff(source.attributes.definitions, target.attributes.definitions)

        file_length_difference = 0
        diffs.each do |piece|
          hunk = ::Diff::LCS::Hunk.new(source.attributes.definitions, target.attributes.definitions, piece, 0, file_length_difference)
          file_length_difference = hunk.file_length_difference
          output << hunk.diff(:unified).gsub(/^/, '   ') << "\n"
        end
        output << "*/" << "\n"
        output << source.drop_statement << "\n"
        output << target.create_statement << "\n"
        output << "\n"
      end

      # --- Indexes ----


      # @to_compare = []
      # @new_database.tables.each do |name, table|
      #   unless @old_database.tables.has_key?(name)
      #     add_script(:tables_create ,  table.create_statement)
      #     add_script(:indices_create ,  table.index_creation) unless table.indexes.empty?
      #     @to_compare << name
      #   else
      #     diff_attributes(@old_database.tables[name], table)
      #     diff_indexes(@old_database.tables[name], table)
      #     @to_compare << name
      #   end
      # end
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

    def self.from_database(connection, ignore_schemas = Database::SYSTEM_SCHEMAS)
      query = <<~EOT
        SELECT pg_class.oid, pg_namespace.nspname, pg_class.relname, pg_class.relkind
        FROM pg_catalog.pg_class
        LEFT JOIN pg_catalog.pg_user ON pg_class.relowner = pg_user.usesysid 
        LEFT JOIN pg_catalog.pg_namespace ON pg_class.relnamespace = pg_namespace.oid 
        WHERE pg_class.relkind = 'r'
          #{ignore_schemas.empty? ? "" : "AND pg_namespace.nspname NOT IN (#{ignore_schemas.join(', ')})"}
        ORDER BY 1,2;
      EOT

      connection.query(query).reduce(Set.new) do |set, record|
        set << new(connection, record['oid'], record['nspname'], record['relname'])
        set
      end
    end
    
    def initialize(connection, oid, schema, table_name)
      @oid = oid
      @schema = schema
      @name = table_name
      @attributes = {}
      @constraints = {}
      @indexes = Index.from_database(connection, self)
      @attributes = Attributes.from_database(connection, self)

      # cons_query = <<~EOT
      #   select conname, pg_get_constraintdef(oid) from pg_constraint where conrelid = '#{schema}.#{table_name}'::regclass
      # EOT
      #
      # connection.query(cons_query).each do |tuple|
      #   name = tuple['conname']
      #   value = tuple['pg_get_constraintdef']
      #   @constraints[name] = value
      # end
      #
      # @constraints.keys.each do |cname|
      #   @indexes.delete("#{schema}.#{cname}") if has_index?(cname)
      # end
    end

    def qualified_name
      "#{self.schema}.#{self.name}"
    end

    def eql?(other)
      self.qualified_name == other.qualified_name &&
        self.attributes == other.attributes
    end

    def hash
      self.qualified_name.hash
    end

    def has_index?(name)
      @indexes.has_key?(name) || @indexes.has_key?("#{schema}.#{name}")
    end

    def has_constraint?(name)
      @constraints.has_key?(name)
    end

    def index_creation
      out = []
      @indexes.values.each do |c|
        out << (c+";")
      end
      out.join("\n")
    end

    def create_statement
      attribute_definitions = @attributes.map do |attribute|
        attribute.definition
      end

      statement = <<~EOT
        CREATE TABLE #{qualified_name}
        (
          #{attribute_definitions.join(",\n  ")}
        );
      EOT
      statement.strip
    end

    def drop_statement
      "DROP TABLE #{qualified_name} CASCADE;"
    end

    def to_s
      self.qualified_name
    end
    alias :inspect :to_s

  end
end