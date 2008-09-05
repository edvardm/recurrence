=begin rdoc
Simple class for recurring things. The idea is to decouple recurrence completely from other objects. A Recurrence instance
offers two key methods for finding out if something recurs at given date: the method <tt>recurs_on?(time)</tt> and +each+ to iterate through recurrences.
=end

# Edvard Majakari <edvard.majakari@adalia.fi>

require 'date' # for computing days in month

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
    # TODO: make repeat intervals more consistent, so that only every_second is needed instead of every_other, and the semantics
    # depend whether the argument is one of [day, week, month, year] OR weekdays
    attr_reader :recur_from, :recur_until

    _RECURRENCES = [:day, :week, :month, :year]
    _RECURRENCE_EXTENSIONS = [:workday, :weekend]

    DAYS = [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]
    RECURRENCE_SELECTORS = {
      :every => _RECURRENCES + _RECURRENCE_EXTENSIONS,
      :every_first => DAYS,
      :every_second => DAYS,
      :every_last => DAYS,
      :every_other => _RECURRENCES,
      :every_third => _RECURRENCES,
      :every_nth => _RECURRENCES
      }

    # Return true if the instance recurs on given time. Note that only the date part is taken into account. Support the same
    # time arguments as +new+.
    def recurs_on?(time_thing)
      time = evaluate_time_arg(time_thing)
      return false unless time_between_begin_end(time)

      case @_recurrence_repeat
      when :every
        repeat_every_since(recur_from, time, @_recurrence_type)
      when :every_other, :every_third, :every_nth
        recurrence_repeats_on? recur_from, time, @_recurrence_type, every_star_to_num
      when :every_first, :every_second, :every_last
        sym_to_num = {:every_first => 1, :every_second => 2, :every_last => -1}
        n = sym_to_num[@_recurrence_repeat]
        weekday = @_recurrence_type
        weekday_is_nth_in?(n, @_recurrence_options[:of], weekday, time)
      else
        raise "No you can't has cheezburger with repeat #{@_recurrence_repeat}"
      end
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
      format ||= :long
      wday = DAYS[@recur_from.wday]
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
    def each_recurrence
      time = @recur_from

      multiplier = every_star_to_num
        
      rtype = @_recurrence_type
      old_time = time
      orig_day = time.day
      loop do
        yield time
        if rtype == :day
          time += multiplier*86400
        elsif rtype == :week
          time += multiplier*86400*7
        elsif rtype == :month
          y, m, d = time.year, time.mon, time.day
          m += every_star_to_num
          y_inc, m_rem = m.divmod 13
          m_rem = 1 if m_rem.zero?
          y += y_inc
          dim = Date.days_in_month(y, m_rem)
          d = [dim, orig_day].min
          time = Time.local(y, m_rem, d)
        elsif rtype == :year
          y, m, d = time.year, time.mon, time.day
          time = Time.local(y+every_star_to_num, m, d)
        else
          raise ArgumentError, "Oh noes! #{rtype}!"
        end

        # make sure the time changes in the loop!
        fail unless time > old_time
        old_time = time
      end
    end

    # end of public instance methods

    private

    def every_star_to_num
      hsh = {
        :every => 1,
        :every_other => 2,
        :every_third => 3,
        :every_nth => @_recurrence_options[:interval]
      }
      hsh[@_recurrence_repeat]
    end

    def parse_recurrence_options(opts)
      repeat = opts.keys.detect { |key| RECURRENCE_SELECTORS.include? key }
      raise ArgumentError, "missing required repeat modifier" unless repeat
      recurrence_type = opts[repeat]

      err_msg = "invalid recurrence type #{recurrence_type} for repeat #{repeat}"
      raise ArgumentError,  err_msg unless RECURRENCE_SELECTORS[repeat].include? recurrence_type
      [repeat, recurrence_type]
    end
    
    # create new time object using time, ignoring hours, minutes and seconds
    def date_delta(recur_from, time)
      d_sec = Time.local(time.year, time.month, time.day).to_i - Time.local(recur_from.year, recur_from.month, recur_from.day).to_i
      d_sec / 86400
    end

    def weekend?(time)
      [:sunday, :saturday].include? DAYS[time.wday]
    end

    def repeat_every_since(recur_from, time, recurrence_type)
      case recurrence_type
      when :weekend
        weekend?(time)
      when :workday
        !weekend?(time)
      else
        recurrence_repeats_on?(recur_from, time, recurrence_type, 1)
      end
    end

    def recurrence_repeats_on?(recur_from, time, recurrence_type, n)
      case recurrence_type
      when :day
        date_delta(recur_from, time) % n == 0
      when :week
        date_delta(recur_from, time) % (n*7) == 0
      when :month
        recur_from.day == time.day && (time.mon - recur_from.mon) % n == 0
      when :year
        recur_from.day == time.day && recur_from.mon == time.mon && (time.year - recur_from.year) % n == 0
      else
        raise ArgumentError, "invalid recurrence type #{@_recurrence_type}"
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

    def evaluate_time_arg(t)
      case t
      when Time
        Time.local(t.year, t.mon, t.day) # discard extra resolution not used in for time comparisons
      when String
        Time.local(*t.split('-'))
      when Array
        Time.local(*t)
      when Symbol
        symbol_to_time(t)
      else
        raise ArgumentError, "invalid time format #{t.inspect}"
      end
    end

    def symbol_to_time(sym)
      case sym
      when :epoch
        Time.local(1970, 1, 1)
      else
        raise ArgumentError, "invalid time spec #{sym}"
      end
    end

    def time_between_begin_end(time)
      prereq = recur_from <= time
      @recur_until ? prereq && time <= @recur_until : prereq
    end
  end
end


# Class for creating recurring objects. Also see the module RecurrenceBase::RecurrenceMixin for basic methods and
# RecurrenceBase::RecurrenceMixin for supported set operations.
class Recurrence
  include RecurrenceBase::SetOperations
  include RecurrenceBase::RecurrenceMixin
  
  alias :each :each_recurrence # each is more convenient with Recurrence instances, but in a mixin it would probably be a bad idea

  # Instantiate a new object. +init_time+ can be any of the following four argument types:
  # - Time instance
  # - Date string of the form yyyy-mm-dd
  # - Array of integers [Y, m, d] (eg. [2008, 7, 25])
  # - Special symbol :epoch, denoting the common *nix time epoch 1970-01-01
  #
  # +init_time+ is used for deferring whether the recurrence is valid at given time. All calls to recurs_on?
  # with time before +init_time+ return false.
  #
  # The second argument is the hash specifying the recurrence. The hash key represents the frequency
  # of the recurrence (:every, :every_first, :every_second, :every_other, :every_third, :every_nth)
  # and the value specifies the time unit (:day, :week, :month, :year). 
  # 
  # *Note* that every_first and every_second refer to specific _weekday_ and make sense only with monthly and yearly
  # recurrences. They also require the argument :of. That is, the semantics depend on the context of all the arguments. 
  #
  # For example:
  #
  #  Recurrence.new(:epoch, :every_other => :day) # recur every other day
  #  Recurrence.new(:epoch, :every_nth => :day, :interval => 10) # recur every 10th day
  #
  #  Recurrence.new(:epoch, :every_first => :wednesday, :of => :month) # recur only on the first wednesday of a month
  #  Recurrence.new(:epoch, :every_last => :thursday, :of => :month) # recur on the last thursday of a month
  #
  #  Recurrence.new([2008, 1, 7], :every => :week) # 2008-01-07 was monday, so recur every monday
  #  Recurrence.new([2008, 1, 4], :every => :month) # Recur on 4th day of every month

  def initialize(init_time, options)
    @recur_from = evaluate_time_arg(init_time)

    @recur_until = options.delete(:until)
    @recur_until = evaluate_time_arg(@recur_until) if @recur_until

    @_recurrence_repeat, @_recurrence_type = parse_recurrence_options(options)
    @_recurrence_options = options
  end
end