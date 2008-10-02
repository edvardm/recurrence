=begin rdoc
Simple class for recurring things. The idea is to decouple recurrence completely from other objects. A Recurrence instance
offers two key methods for finding out if something recurs at given date: the method <tt>recurs_on?(time)</tt> and +each+ to iterate through recurrences.
=end

# Edvard Majakari <edvard.majakari@adalia.fi>

require 'date'

class Date
  def self.days_in_month(year, mon) # convenience method
    civil(year, mon, -1).day
  end
end

# Namespace for Recurrence support classes and modules
module RecurrenceBase
  module SetOperations
    # Return complement of the recurrence, ie. return value of recurs_on? is negated.
    def complement
      RecurrenceComplement.new(self, nil)
    end

    # Return union of the recurrences. For any recurrences or sets of recurrences +a+ and +b+, <tt>(a.join b).recurs_on?(t)</tt>
    # returns true _iff_ either a OR b recurs on t.
    def join(recurrence)
      RecurrenceUnion.new(self, recurrence)
    end 
    alias :| :join

    # Return intersection of the recurrences. For any recurrences or sets of recurrences +a+ and +b+, <tt>(a.intersect b).recurs_on?(t)</tt>
    # returns true _iff_ both a AND b recur on t.
    def intersect(recurrence)
      RecurrenceIntersection.new(self, recurrence)
    end
    alias :& :intersect

    # Return difference of the recurrences. Note that the order is now significant. For any recurrences or sets of recurrences +a+ and +b+, <tt>(a.diff b).recurs_on?(t)</tt>
    # returns true _iff_ a recurs on t AND b does NOT recur on t.
    def diff(recurrence)
      RecurrenceDifference.new(self, recurrence)
    end
    alias :- :diff
  end
  
  class RecurrenceProxy
    include SetOperations

    def initialize(a, b)
      @a = a
      @b = b
    end
    
    def class
      ::Recurrence
    end
  end

  class RecurrenceUnion < RecurrenceProxy
    def recurs_on?(t)
      @a.recurs_on?(t) or @b.recurs_on?(t)
    end
  end

  class RecurrenceIntersection < RecurrenceProxy
    def recurs_on?(t)
      @a.recurs_on?(t) and @b.recurs_on?(t)
    end
  end

  class RecurrenceComplement < RecurrenceProxy
    def recurs_on?(t)
      !@a.recurs_on?(t)
    end
  end

  class RecurrenceDifference < RecurrenceProxy
    def recurs_on?(t)
      @a.recurs_on?(t) and !@b.recurs_on?(t)
    end
  end
  
  class RecurrenceSymmetricDifference < RecurrenceProxy
    def recurs_on?(t)
      @a.recurs_on?(t) && !@b.recurs_on?(t) or !@a.recurs_on?(t) && @b.recurs_on?(t)
    end
  end

  module RecurrenceMixin
    attr_reader :recur_until

    _RECURRENCES = [:day, :week, :month, :year]
    _RECURRENCE_EXTENSIONS = [:workday, :weekend]

    DAYS = [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]
    DAILY_RECURRENCES = DAYS + _RECURRENCES
    
    RECURRENCE_SELECTORS = {
      :every => DAILY_RECURRENCES + _RECURRENCE_EXTENSIONS,
      :every_first => DAILY_RECURRENCES,
      :every_second => DAILY_RECURRENCES,
      :every_third => DAILY_RECURRENCES,
      :every_last => DAILY_RECURRENCES,
      :every_nth => DAILY_RECURRENCES
      }

    # Return true if the instance recurs on given time. Note that only the date part is taken into account. Support the same
    # time arguments as +new+.
    def recurs_on?(date_thing)
      date = evaluate_date_arg(date_thing)
      return false unless date_between_begin_end(date)

      case @recurrence_repeat
      when :every
        repeat_every_since(start_date, date, @recurrence_type)
      when :every_first, :every_second, :every_third, :every_last, :every_nth
        if !@recurrence_options[:of]
          recurrence_repeats_on? start_date, date, @recurrence_type, every_star_to_num
        else
          sym_to_num = {:every_first => 1, :every_second => 2, :every_third => 3, :every_last => -1}
          n = sym_to_num[@recurrence_repeat]
          weekday = @recurrence_type
          weekday_is_nth_in?(n, @recurrence_options[:of], weekday, date)
        end
      else
        raise "Oh noes1!1! Cheezburger denied wid rekorrenz repiet #{@recurrence_repeat}"
      end
    end
    
    def recur_from
      deprecation_warning(:recur_from, :start_date)
      start_date
    end
    
    def deprecation_warning(deprecated_method, new_method)
      klass = self.class
      warn "#{klass}##{deprecated_method} is deprecated, please use #{klass}##{new_method} instead"
    end
    
    def start_date
      r = @recur_from
      Date.new(r.year, r.month, r.day)
    end

    # Return weekday symbol of the initial time used for recurrence (eg. :monday). The optional format can be either <tt>:long</tt>    
    # (default) or <tt>:short</tt>.
    #
    # Examples:
    #
    #  r = Recurrence.new([2008, 1, 1], :every => :day)
    #  r.starting_dow # => :tuesday 
    #  r.starting_dow(:short) # => :tue
    def starting_dow(format=nil)
      # TODO: rather modify Date class locally so that it returns weekday symbol
      format ||= :long
      wday = DAYS[start_date.wday]
      case format
      when :long
        wday
      when :short
        wday.to_s[0..2].to_sym
      else
        raise ArgumentError, 'invalid format'
      end
    end

    # Iterate through all recurrences, always yielding the next time object. 
    # WARNING: incomplete implementation. Only works for every_nth daily recurrences for now.
    def each_day
      date = start_date
      multiplier = every_star_to_num
        
      rtype = @recurrence_type
      old_date = date.dup
      orig_day = date.day
      
      if weekday_recurrence?(rtype)
        day_diff = DAYS.index(rtype) - date.wday
        day_diff = 7 + day_diff if day_diff < 0
        date += day_diff
      end
      
      loop do
        yield date
        if rtype == :day
          date += multiplier
        elsif rtype == :week || weekday_recurrence?(rtype)
          date += multiplier*7
        elsif rtype == :month
          y, m, d = date.year, date.mon, date.day
          m += every_star_to_num
          y_inc, m_rem = m.divmod 13
          m_rem = 1 if m_rem.zero?
          y += y_inc
          dim = Date.days_in_month(y, m_rem)
          d = [dim, orig_day].min
          date = Date.new(y, m_rem, d)
        elsif rtype == :year
          y, m, d = date.year, date.mon, date.day
          date = Date.new(y+every_star_to_num, m, d)
        else
          raise ArgumentError, "Oh noes! #{rtype}!"
        end

        # make sure the date changes in the loop!
        fail unless date > old_date
        old_date = date
      end
    end

    # end of public instance methods

    private

    def weekday_recurrence?(rtype)
      DAYS.include? rtype
    end
    
    def every_star_to_num
      hsh = {
        :every => 1,
        :every_second => 2,
        :every_third => 3,
        :every_nth => @recurrence_options[:interval]
      }
      hsh[@recurrence_repeat]
    end

    def parse_recurrence_options(opts)
      repeat = opts.keys.detect { |key| RECURRENCE_SELECTORS.include? key }
      raise ArgumentError, "missing required repeat modifier" unless repeat
      recurrence_type = opts[repeat]

      err_msg = "invalid recurrence type #{recurrence_type} for repeat #{repeat}"
      raise ArgumentError,  err_msg unless RECURRENCE_SELECTORS[repeat].include? recurrence_type
      [repeat, recurrence_type]
    end
    
    def date_delta(from_date, to_date)
      (to_date - from_date).to_i # :- returns Rational, so we need to_i
    end

    def weekend?(time)
      [:sunday, :saturday].include? DAYS[time.wday]
    end

    def repeat_every_since(start_date, time, recurrence_type)
      case recurrence_type
      when :weekend
        weekend?(time)
      when :workday
        !weekend?(time)
      else
        recurrence_repeats_on?(start_date, time, recurrence_type, 1)
      end
    end

    def recurrence_repeats_on?(start_date, time, recurrence_type, n)
      case recurrence_type
      when :day
        date_delta(start_date, time) % n == 0
      when :week
        date_delta(start_date, time) % (n*7) == 0
      when :month
        start_date.day == time.day && (time.mon - start_date.mon) % n == 0
      when :year
        start_date.day == time.day && start_date.mon == time.mon && (time.year - start_date.year) % n == 0
      when *DAYS
        DAYS[time.wday] == recurrence_type
      else
        raise ArgumentError, "invalid recurrence type #{@recurrence_type}"
      end
    end

    def weekday_is_nth_in?(n, period, weekday, time)
      case period
      when :month
        nth_weekday_in_month?(n, weekday, time)
      else 
        raise ArgumentError, 'oh noes'
      end
    end

    def nth_weekday_in_month?(n, weekday, time)
      if n == -1
        dim = Date.days_in_month(time.year, time.mon)
        DAYS[time.wday] == weekday && time.day > dim - 7
      elsif n > 1 
        DAYS[time.wday] == weekday && time.day > 7*(n-1) && time.day <= 7*n
      else
        DAYS[time.wday] == weekday && time.day < 8
      end
    end

    def evaluate_date_arg(time_arg)
      # TODO: raise error on nil
      case time_arg
      when String
        Date.parse(time_arg)
      when Array
        Date.new(*time_arg)
      when Symbol
        symbol_to_date(time_arg)
      when nil, Date
        time_arg
      when Time
        Date.new(time_arg.year, time_arg.month, time_arg.day)
      else
        raise ArgumentError, "invalid timey thing passed as argument: #{time_arg.inspect}"
      end
    end

    def symbol_to_date(sym)
      case sym
      when :epoch
        Date.new(1970, 1, 1)
      when :now
        Date.today
      else
        raise ArgumentError, "invalid date spec #{sym}"
      end
    end

    def date_between_begin_end(date)
      prereq = start_date <= date
      @recur_until ? prereq && date <= @recur_until : prereq
    end
  end
end


# Class for creating recurring objects. Also see the module RecurrenceBase::RecurrenceMixin for basic methods and
# RecurrenceBase::RecurrenceMixin for supported set operations.
class Recurrence
  include RecurrenceBase::SetOperations
  include RecurrenceBase::RecurrenceMixin
  
  alias :each :each_day # each is more convenient with Recurrence instances, but in a mixin it would probably be a bad idea

  # Instantiate a new object. +init_time+ can be any of the following four argument types:
  # - Date instance
  # - Date string of the form yyyy-mm-dd
  # - Time instance (only date part will be taken into account)
  # - Array of integers [Y, m, d] (eg. [2008, 7, 25])
  # - Special symbol :epoch, denoting the common *nix time epoch 1970-01-01
  # - Special symbol :now, denoting the current day
  #
  # +init_time+ is used for deferring whether the recurrence is valid at given time. All calls to recurs_on?
  # with time before +init_time+ return false. The hour/minute part is ignored.
  #
  # The second argument is the option hash specifying the type of recurrence. The hash key represents the frequency
  # of the recurrence (:every, :every_first, :every_second, :every_third, :every_nth)
  # and the value specifies the time unit :day, :week, :month, :year (sometimes also :weekend or specific day of the week,
  # see below). 
  # 
  # *Note* that every_first and every_second refer to specific _weekday_ and make sense only with monthly and yearly
  # recurrences. They also require additional information like :of => :month or :of => :year. 
  #
  # Examples:
  #
  #  Recurrence.new(:epoch, :every_second => :day) # recur every other day, starting from epoch
  #  Recurrence.new(:epoch, :every_nth => :day, :interval => 10) # recur every 10th day, starting from epoch
  #
  #  # recur only on the first wednesday of a month starting from today
  #  Recurrence.new(:today, :every_first => :wednesday, :of => :month) 
  #
  #  # recur only on every last thursday of a month, starting from today
  #  Recurrence.new(:today, :every_last => :thursday, :of => :month)
  #
  #  Recurrence.new([2008, 10, 7], :every => :week) # 2008-01-07 was xday, so recur every xday
  #  Recurrence.new([2008, 10, 7], :every => :wednesday) # recur every wednesday starting from 2008-10-07
  #  Recurrence.new("2008-09-04", :every => :month) # Recur on the 4th day of every month
  def initialize(init_time, options)
    @recur_from = evaluate_date_arg(init_time)

    @recur_until = evaluate_date_arg(options.delete(:until))

    @recurrence_repeat, @recurrence_type = parse_recurrence_options(options)
    @recurrence_options = options
  end
end