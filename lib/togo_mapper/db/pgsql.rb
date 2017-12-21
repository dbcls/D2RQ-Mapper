require 'pg'
require 'togo_mapper/db/common'

module TogoMapper
class DB
class Pgsql < TogoMapper::DB::Common

  def initialize(connection_config)
    @database = connection_config.delete(:database)
    connection_config[:user] = connection_config.delete(:username)
    connection_config[:dbname] = @database
    if connection_config[:host] == 'localhost'
      connection_config[:host] = '127.0.0.1'
    end
    @client = PG.connect(connection_config)
  end


  def tables
    query = "SELECT table_name FROM information_schema.tables WHERE table_catalog='#{escape(@database)}' AND table_schema='public'"
    @client.exec(query).map{ |row| row["table_name"] }.select{ |name| name[0 .. 6] != 'togodb_' && name != 'schema_migrations' && name != 'sessions' }
  end


  def columns(table)
    query = "SELECT column_name FROM information_schema.columns WHERE table_name='#{escape(table)}'"
    @client.exec(query).map{ |row| row["column_name"] }
  end


  def records(table, offset = 0, limit = 5)
    query = sql_for_fetch_example_records(table, offset, limit)
    puts "#{'=' * 80}\n#{query}"

    rows = []
    @client.query(query).each do |row|
      rows << row
    end

    rows
  end

  
  def offset_limit_phase(offset = 0, limit = 5)
    if offset == 0
      "LIMIT #{limit}"
    else
      "OFFSET #{offset} LIMIT #{limit}"
    end
  end

  
  def pk_info(database, table)
    info = {}
    primary_keys = []

    query = <<-EOS
SELECT
    TC.TABLE_NAME           AS TABLE_NAME
,   TC.CONSTRAINT_NAME      AS CONSTRAINT_NAME
,   COL.COLUMN_NAME         AS COLUMN_NAME
,   COL.ORDINAL_POSITION    AS POSITION
FROM
    INFORMATION_SCHEMA.TABLE_CONSTRAINTS TC
    INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE CCU ON
        TC.TABLE_NAME       = CCU.TABLE_NAME
    AND TC.CONSTRAINT_NAME  = CCU.CONSTRAINT_NAME
    INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE COL ON
        TC.TABLE_CATALOG    = COL.TABLE_CATALOG
    AND TC.TABLE_SCHEMA     = COL.TABLE_SCHEMA
    AND TC.TABLE_NAME       = COL.TABLE_NAME
    AND CCU.COLUMN_NAME     = COL.COLUMN_NAME
WHERE
    TC.CONSTRAINT_TYPE = 'PRIMARY KEY'
    AND TC.TABLE_NAME = '#{escape(table)}'
ORDER BY
    TC.TABLE_NAME
,   COL.ORDINAL_POSITION
EOS

    @client.query(query).each do |row|
      primary_keys << row['column_name']
    end
    info[:column_name] = primary_keys.join(',')
    
    info
  end

  
  def close
    @client.finish
  end


  def escape(s)
    @client.escape_string(s)
  end

end
end
end
