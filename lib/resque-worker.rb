#!/usr/bin/env ruby
# coding: utf-8

require File.expand_path('../../config/application', __FILE__)
Rails.application.require_environment!

class ResqueWorkerDaemon < DaemonSpawn::Base
  def start(args)
    begin
      @worker = Resque::Worker.new('d2rq_turtle_generator_r5')
      @worker.verbose = true
      @worker.work
    rescue => e
      STDERR.puts 'Resque worker was not started up due to the following reasons.'
      STDERR.puts e.message
    end
  end

  def stop
    @worker.try(:shutdown)
  end
end

ResqueWorkerDaemon.spawn!(
  {
    processes:   3,
    working_dir: Rails.root,
    pid_file:    File.join(Rails.root, 'tmp', 'pids', 'resque_worker.pid'),
    log_file:    File.join(Rails.root, 'log', 'resque_worker.log'),
    sync_log:    true,
    singleton:   true,
    signal:      'QUIT'
  }
)
