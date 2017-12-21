module TogoMapper
module Connection

  def connect_database(password)
    cp = connection_properties(password)

    model_base_class.establish_connection(cp)
  end

  
  def connection_properties(password)
    db_connection = @work.db_connection
    case db_connection.adapter
    when 'mysql2'
      encoding = 'utf8'
    when 'postgresql'
      encoding = 'unicode'
    end

    host = (db_connection.host.blank? or db_connection.host == 'localhost') ? '127.0.0.1' : db_connection.host
    port = db_connection.port.blank? ? nil : db_connection.port.to_i

    {
      adapter: db_connection.adapter,
      encoding: encoding,
      database: db_connection.database,
      host: host,
      port: port,
      username: db_connection.username,
      password: password
    }
  end


  def model_base_class_name
    "job#{@work.id}_#{@work.db_connection.database.gsub(/[^A-Za-z0-9_]/, "_")}".classify
  end

  
  def model_base_class
    begin
      self.class.const_get(model_base_class_name)
    rescue
      ar_class = self.class.const_set(model_base_class_name, Class.new(ActiveRecord::Base))
      ar_class.abstract_class = true
      ar_class
    end
  end


  def model_class_name(table_name)
    #"job#{@work.id}_#{@work.db_connection.database.gsub(/[^A-Za-z0-9_]/, "_")}_#{table_name}".classify
    "job#{@work.id}_#{@work.db_connection.database.gsub(/[^A-Za-z0-9_]/, "_")}_#{table_name.gsub(/[^A-Za-z0-9_]/, "_")}".classify
  end

  
  def model_class(table_name)
    begin
      model = self.class.const_get(model_class_name(table_name))
    rescue
      model = self.class.const_set(model_class_name(table_name), Class.new(model_base_class))
      model.table_name = table_name
    end

    model
  end

  
  def disconnect
    model_base_class.remove_connection
  end

end
end
