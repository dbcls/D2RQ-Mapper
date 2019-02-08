namespace :d2rq_mapper do

  desc "Setup D2RQ Mapper"
  task :setup do
    Rake::Task['db:setup'].invoke
    
    required_paths = [
      "#{Rails.root}/data/turtle",
      "#{Rails.root}/data/tmp",
      "#{Rails.root}/tmp/pids"
    ]

    required_paths.each do |path|
      FileUtils.mkdir_p(path) unless File.exist?(path)
    end

    cipher = 'aes-256-cbc'
    salt = SecureRandom.random_bytes(64)
    key_len = ActiveSupport::MessageEncryptor.key_len(cipher)
    key = ActiveSupport::KeyGenerator.new('password').generate_key(salt, key_len).unpack("H*")
    File.open("#{Rails.root}/config/secrets.yml", 'w') do |f|
      $stdout = StringIO.new
      
      Rake::Task['secret'].invoke
      secret_key_base = $stdout.string
      f.puts("development:")
      f.puts("  secret_key_base: #{secret_key_base}")
      f.puts("  enc_key: #{key}")
      f.puts("  enc_cipher: #{cipher}")

      Rake::Task['secret'].invoke
      secret_key_base = $stdout.string
      f.puts("test:")
      f.puts("  secret_key_base: #{secret_key_base}")
      f.puts("  enc_key: #{key}")
      f.puts("  enc_cipher: #{cipher}")

      f.puts("production:")
      f.puts('  secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>')
      f.puts("  enc_key: #{key}")
      f.puts("  enc_cipher: #{cipher}")

      $stdout = STDOUT
    end
  end

end
