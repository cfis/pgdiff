module PgDiff
  class Table
    attr_accessor :oid, :schema, :name, :attributes, :constraints, :indexes

    def self.compare(sources, targets, output)
      drops = []
      creates = []
      changes = []

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
            changes << [source, target]
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

      changes.each do |source, target|
        if !source.attributes.eql?(target.attributes)
          output << "/* Table " << source.qualified_name << " has changed attributes" << "\n"
          Attributes.compare(source.attributes, target.attributes, output)
          output << source.drop_statement << "\n"
          output << target.create_statement << "\n"
          output << "\n"
        else
          output << "/* Table " << source.qualified_name << " has changed constraints */" << "\n"
          Constraints.compare(source.constraints, target.constraints, output)
        end
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
      @constraints = Constraints.from_database(connection, self)
    end

    def qualified_name
      "#{self.schema}.#{self.name}"
    end

    def eql?(other)
      self.qualified_name == other.qualified_name &&
        self.attributes == other.attributes &&
        self.constraints == other.constraints
    end

    def hash
      self.qualified_name.hash
    end

    def has_index?(name)
      @indexes.has_key?(name) || @indexes.has_key?("#{schema}.#{name}")
    end

    def index_creation
      out = []
      @indexes.values.each do |c|
        out << (c+";")
      end
      out.join("\n")
    end

    def create_statement
      definitions = @attributes.definitions + @constraints.definitions

      statement = <<~EOT
        CREATE TABLE #{qualified_name}
        (
        #{definitions.join(",\n").gsub(/^/, "  ")}
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