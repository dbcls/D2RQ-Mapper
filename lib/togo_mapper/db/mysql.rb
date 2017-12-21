require 'mysql2'

module TogoMapper
class DB
class Mysql < TogoMapper::DB::Common

  def initialize(connection_config)
    if connection_config[:host] == 'localhost'
      connection_config[:host] = '127.0.0.1'
    end
    @client = Mysql2::Client.new(connection_config)
    @database = connection_config[:database]
  end


  def tables
    query = "SELECT table_name FROM information_schema.tables WHERE table_schema='#{escape(@database)}'"
    @client.query(query).map{ |row| row["table_name"] }
  end


  def columns(table)
    return [] if table.blank?
    query = "SHOW COLUMNS FROM `#{escape(table)}`"
    @client.query(query).map{ |row| row["Field"] }
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


  def pk_info(database, table)
    info = {}

    query = "SELECT * FROM information_schema.columns c WHERE  c.table_schema = '#{database}' AND  c.table_name = '#{table}' AND  c.column_key = 'PRI' ORDER BY ordinal_position"
    @client.query(query).each do |row|
      info[:column_name] = row['COLUMN_NAME']
    end

    info
  end


  def close
    @client.close
  end


  def escape(s)
    @client.escape(s.to_s)
  end


  def identifier_quotation_char
    %Q|`|
  end
  
end
end
end
