require 'togo_mapper/db/common'

module TogoMapper
class DB
  attr_reader :client
  
  def initialize(connection_config)
    adapter = connection_config.delete(:adapter)
    case adapter
    when 'mysql2'
      require 'togo_mapper/db/mysql'
      @client = TogoMapper::DB::Mysql.new(connection_config)
    when 'postgresql'
      require 'togo_mapper/db/pgsql'
      @client = TogoMapper::DB::Pgsql.new(connection_config)
    when 'sqlite3'
      require 'togo_mapper/db/sqlite'
      @client = TogoMapper::DB::SQLite.new(connection_config)
    end
  end


  def tables
    @client.tables
  end


  def columns(table)
    @client.columns(table)
  end


  def records(table, offset = 0, limit = 5)
    @client.records(table, offset, limit)
  end


  def close
    @client.close
  end

end
end
