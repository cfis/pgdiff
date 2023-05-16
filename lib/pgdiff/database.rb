module PgDiff
  class Database
    attr_accessor :tables, :views, :sequences, :schemas, :domains, :rules, :functions, :triggers

    def initialize(conn)
      cls_query = <<-EOT
        SELECT n.nspname, c.relname, c.relkind
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('r','S','v')
        AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
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

      conn.query(cls_query).each do |tuple|
        schema = tuple['nspname']
        relname = tuple['relname']
        relkind = tuple['relkind']
        case relkind
          when 'r'
            @tables["#{schema}.#{relname}"] = Table.new(conn, schema, relname)
          when 'v'
            @views["#{schema}.#{relname}"] = View.new(conn, schema, relname)
          when 'S'
            @sequences["#{schema}.#{relname}"] = Sequence.new(conn, schema, relname)
        end
      end

      domain_qry = <<-EOT
      SELECT n.nspname, t.typname,  pg_catalog.format_type(t.typbasetype, t.typtypmod) || ' ' ||
         CASE WHEN t.typnotnull AND t.typdefault IS NOT NULL THEN 'not null default '||t.typdefault
              WHEN t.typnotnull AND t.typdefault IS NULL THEN 'not null'
              WHEN NOT t.typnotnull AND t.typdefault IS NOT NULL THEN 'default '|| t.typdefault
              ELSE ''
         END AS def
      FROM pg_catalog.pg_type t
         LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
      WHERE t.typtype = 'd'
      ORDER BY 1, 2
      EOT
      conn.query(domain_qry).each do |tuple|
        schema = tuple['nspname']
        typename = tuple['typname']
        value = tuple['def']
        @domains["#{schema}.#{typename}"] = value
      end

      schema_qry = <<-EOT
        select nspname from pg_namespace
      EOT
      conn.query(schema_qry).each do |tuple|
        schema = tuple['nspname']
        @schemas[schema] = schema
      end

      func_query = <<-EOT
       SELECT proname AS function_name
       , nspname AS namespace
       , lanname AS language_name
       , pg_catalog.obj_description(pg_proc.oid, 'pg_proc') AS comment
       , proargtypes AS function_args
       , proargnames AS function_arg_names
       , prosrc AS source_code
       , proretset AS returns_set
       , prorettype AS return_type,
       provolatile, proisstrict, prosecdef
       FROM pg_catalog.pg_proc
       JOIN pg_catalog.pg_language ON (pg_language.oid = prolang)
       JOIN pg_catalog.pg_namespace ON (pronamespace = pg_namespace.oid)
       JOIN pg_catalog.pg_type ON (prorettype = pg_type.oid)
       WHERE pg_namespace.nspname !~ 'pg_catalog|information_schema'
       AND proname != 'plpgsql_call_handler'
       AND proname != 'plpgsql_validator'
      EOT

      conn.exec(func_query).each_with_index do |tuple, i|
        func = Function.new(conn, tuple)
        @functions[func.signature] = func
      end

      rule_query = <<-EOT
      select  schemaname || '.' ||  tablename || '.' || rulename as rule_name,
              schemaname || '.' ||  tablename as tab_name,
        rulename, definition
      from pg_rules
      where schemaname !~ 'pg_catalog|information_schema'
      EOT
      conn.exec(rule_query).each do |tuple|
        @rules[tuple['rule_name']] = Rule.new(tuple['tab_name'], tuple['rulename'], tuple['definition'])
      end

      trigger_query =  <<-EOT
      select nspname || '.' || relname as tgtable, tgname, pg_get_triggerdef(t.oid) as tg_def
      from pg_trigger t join pg_class c ON (tgrelid = c.oid ) JOIN pg_namespace n ON (c.relnamespace = n.oid)
      where not tgisinternal
      and nspname !~ 'pg_catalog|information_schema'
      EOT
      conn.exec(trigger_query).each do |tuple|
        @triggers[tuple['tgtable'] + "." + tuple['tgname']] = Trigger.new(tuple['tgtable'], tuple['tgname'], tuple['tg_def'])
      end
    end
  end
end