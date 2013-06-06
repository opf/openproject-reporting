module Entry
  [TimeEntry, CostEntry].each { |e| e.send :include, self }

  class Delegator < ActiveRecord::Base
    # Rails 3.2.13 delegates most of the methods defined here to an
    # ActiveRecord::Relation (see active_record/querying.rb).
    # Thus only implementing the four find_x methods isn't enough
    # Rails 2.3 internally called these e.g. for all().
    # A quick fix is implementing all(), but we might need to reconsider how we
    # do the delegation here if more methods were based on the four find_xs.
    self.abstract_class = true
    class << self
      def ===(obj)
        TimeEntry === obj or CostEntry === obj
      end

      def calculate(type, *args)
        a, b = TimeEntry.calculate(type, *args), CostEntry.calculate(type, *args)
        case type
        when :sum, :count then a + b
        when :avg then (a + b) / 2
        when :min then [a, b].min
        when :max then [a, b].max
        else raise NotImplementedError
        end
      end

      undef_method :create, :update, :delete, :destroy, :new, :update_counters,
          :increment_counter, :decrement_counter

      %w[update_all destroy_all delete_all].each do |meth|
        define_method(meth) { |*args| send_all(meth, *args) }
      end

      private
      def all(*args)
        find_many :find, :all, *args
      end

      def count(*args)
        find_many :count, :all, *args
      end

      def find_initial(options)         find_one  :find_initial,  options end
      def find_last(options)            find_one  :find_last,     options end
      def find_every(options)           find_many :find_every,    options end
      def find_from_ids(args, options)  find_many :find_from_ids, options end

      def find_one(*args)
        TimeEntry.send(*args) || CostEntry.send(*args)
      end

      def find_many(*args)
        TimeEntry.send(*args) + CostEntry.send(*args)
      end

      def send_all(*args)
        [TimeEntry.send(*args), CostEntry.send(*args)]
      end
    end
  end

  def units
    super
  rescue NoMethodError
    hours
  end

  def cost_type
    super
  rescue NoMethodError
  end

  def activity
    super
  rescue NoMethodError
  end

  def activity_id
    super
  rescue NoMethodError
  end

  def self.method_missing(*a, &b)
    Delegator.send(*a, &b)
  end
end
