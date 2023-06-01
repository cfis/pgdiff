module PgDiff
  class Table
    attr_accessor :oid, :schema, :name, :attributes, :constraints, :indexes

    def self.compare(sources, targets, output)
      output << "-- ==== Tables ====" << "\n"
      drops = []
      creates = []
      changes = []

      # Create source hash table keyed on index qualified names
      source_hash = sources.each_with_object(Hash.new) do |table, hash|
        hash[table.qualified_name] = table
      end

      # Create target hash table keyed on index qualified names
      target_hash = targets.each_with_object(Hash.new) do |table, hash|
        hash[table.qualified_name] = table
      end

      # Now compare the two hashes to find source only keys (drops), target
      # only keys (creates) and shared keys (changes)
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

      # Process drops
      drops.each do |table|
        output << table.drop_statement << "\n"
      end

      # Process creates
      creates.each do |table|
        output << table.create_statement << "\n"
      end

      # Process changes - are these attribute or constraint changes?
      changes.each do |source, target|
        source.update_statement(target, output)
      end
    end

    def self.from_database(connection, ignore_schemas = Database::SYSTEM_SCHEMAS)
      query = <<~EOT
        SELECT pg_class.oid, pg_namespace.nspname, pg_class.relname, pg_class.relkind
        FROM pg_catalog.pg_class
        JOIN pg_catalog.pg_namespace ON pg_class.relnamespace = pg_namespace.oid 
        WHERE pg_class.relkind = 'r'
          #{ignore_schemas.empty? ? "" : "AND pg_namespace.nspname NOT IN (#{ignore_schemas.join(', ')})"}
        ORDER BY 1,2;
      EOT

      connection.query(query).each_with_object(Set.new) do |record, set|
        set << new(connection, record['oid'], record['nspname'], record['relname'])
      end
    end
    
    def initialize(connection, oid, schema, table_name)
      @oid = oid
      @schema = schema
      @name = table_name
      @attributes = {}
      @constraints = {}
      @attributes = Attributes.from_database(connection, self)
      @constraints = Constraints.from_database(connection, self)
      @indexes = Indexes.from_database(connection, self)
    end

    def qualified_name
      "#{self.schema}.#{self.name}"
    end

    def eql?(other)
      self.qualified_name == other.qualified_name &&
        self.attributes == other.attributes &&
        self.constraints == other.constraints &&
        self.indexes == other.indexes
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

        #{@indexes.map(&:definition).join(",\n").gsub(/^/, "  ")}
      EOT
      statement.strip
    end

    def drop_statement
      "DROP TABLE #{qualified_name} CASCADE;"
    end

    def update_statement(other, output)
      output << "-- ++++ #{other.qualified_name} ++++" << "\n"

      if !self.attributes.eql?(other.attributes)
        output << "-- Attributes --" << "\n"
        Attributes.compare(self.attributes, other.attributes, output)
      end

      if !self.constraints.eql?(other.constraints)
        output << "-- Constraints --" << "\n"
        Constraints.compare(self.constraints, other.constraints, output)
      end

      if !self.indexes.eql?(other.indexes)
        output << "-- Indexes --" << "\n"
        Indexes.compare(self.indexes, other.indexes, output)
      end
    end

    def to_s
      self.qualified_name
    end
    alias :inspect :to_s

  end
end