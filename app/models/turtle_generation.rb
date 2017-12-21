class TurtleGeneration < ApplicationRecord

  class << self

    def last_generation_date(work_id)
      tg = where(work_id: work_id, status: 'SUCCESS').order('id desc').first
      if tg
        tg.end_date
      else
        nil
      end
    end

  end
end
