module PgDiff
  class Database
    attr_accessor :tables, :views, :sequences, :schemas, :domains, :rules, :functions, :triggers

    def initialize(connection, ignore_schemas: [])
      puts "Analyzing #{connection}"
      ignore_schemas += %w['pg_catalog' 'pg_toast' 'information_schema']
      cls_query = <<~EOT
        SELECT n.nspname, c.relname, c.relkind
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('r','S','v')
          AND n.nspname NOT IN (#{ignore_schemas.join(', ')})
        ORDER BY 1,2;
      EOT
      @views = {}
      @tables = {}
      @sequences = {}
      @schemas = {}
      @domains = {}
      @functions = {}
      @rules = {}
      @triggers = {}

      puts "Querying Catalog..."
      connection.query(cls_query).each do |tuple|
        schema = tuple['nspname']
        relname = tuple['relname']
        relkind = tuple['relkind']

        case relkind
          when 'r'
            @tables["#{schema}.#{relname}"] = Table.new(connection, schema, relname)
          when 'v'
            @views["#{schema}.#{relname}"] = View.new(connection, schema, relname)
          when 'S'
            @sequences["#{schema}.#{relname}"] = Sequence.new(connection, schema, relname)
        end
      end

      puts "Querying Domains..."
      domain_qry = <<~EOT
      SELECT n.nspname, t.typname,  pg_catalog.format_type(t.typbasetype, t.typtypmod) || ' ' ||
         CASE WHEN t.typnotnull AND t.typdefault IS NOT NULL THEN 'not null default '|| t.typdefault
              WHEN t.typnotnull AND t.typdefault IS NULL THEN 'not null'
              WHEN NOT t.typnotnull AND t.typdefault IS NOT NULL THEN 'default '|| t.typdefault
              ELSE ''
         END AS def
      FROM pg_catalog.pg_type t
         LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
      WHERE t.typtype = 'd'
        AND n.nspname NOT IN (#{ignore_schemas.join(', ')})
      ORDER BY 1, 2
      EOT
      connection.query(domain_qry).each do |tuple|
        schema = tuple['nspname']
        typename = tuple['typname']
        value = tuple['def']
        @domains["#{schema}.#{typename}"] = value
      end

      puts "Querying Schemas..."
      schema_qry = <<~EOT
        SELECT nspname
        FROM pg_namespace
        WHERE nspname NOT IN (#{ignore_schemas.join(', ')})
      EOT
      connection.query(schema_qry).each do |tuple|
        schema = tuple['nspname']
        @schemas[schema] = schema
      end

      puts "Querying Functions..."
      func_query = <<~EOT
       SELECT proname AS function_name,
         nspname AS namespace,
         lanname AS language_name,
         pg_catalog.obj_description(pg_proc.oid, 'pg_proc') AS comment,
         proargtypes AS function_args,
         proargnames AS function_arg_names,
         prosrc AS source_code,
         proretset AS returns_set,
         prorettype AS return_type,
         provolatile,
         proisstrict,
         prosecdef
       FROM pg_catalog.pg_proc
       JOIN pg_catalog.pg_language ON (pg_language.oid = prolang)
       JOIN pg_catalog.pg_namespace ON (pronamespace = pg_namespace.oid)
       JOIN pg_catalog.pg_type ON (prorettype = pg_type.oid)
       WHERE pg_namespace.nspname NOT IN (#{ignore_schemas.join(', ')})
         AND proname != 'plpgsql_call_handler'
         AND proname != 'plpgsql_validator'
      EOT

      connection.exec(func_query).each_with_index do |tuple, i|
        func = Function.new(connection, tuple)
        @functions[func.signature] = func
      end

      puts "Querying Rules..."
      rule_query = <<~EOT
        SELECT  schemaname || '.' ||  tablename || '.' || rulename AS rule_name,
                schemaname || '.' ||  tablename AS tab_name,
          rulename, definition
        FROM pg_rules
        WHERE schemaname NOT IN (#{ignore_schemas.join(', ')})
      EOT
      connection.exec(rule_query).each do |tuple|
        @rules[tuple['rule_name']] = Rule.new(tuple['tab_name'], tuple['rulename'], tuple['definition'])
      end

      puts "Querying Triggers..."
      trigger_query =  <<~EOT
        SELECT nspname || '.' || relname as tgtable, tgname, pg_get_triggerdef(pg_trigger.oid) as tg_def
        FROM pg_trigger
        JOIN pg_class ON pg_trigger.tgrelid = pg_class.oid
        JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
        WHERE NOT tgisinternal
          AND nspname NOT IN (#{ignore_schemas.join(', ')})
      EOT
      connection.exec(trigger_query).each do |tuple|
        @triggers[tuple['tgtable'] + "." + tuple['tgname']] = Trigger.new(tuple['tgtable'], tuple['tgname'], tuple['tg_def'])
      end
    end
  end
end