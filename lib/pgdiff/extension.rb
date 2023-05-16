module PgDiff
class Extension
    attr_reader :schema, :name, :version
    def initialize(schema, name, version)
      @schema = schema
      @name = name
      @version = version
    end

    def == (other)
      self.name == other.name && self.name == other.name && self.version == other.version
    end
  end
end
