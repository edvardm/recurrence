require File.dirname(__FILE__) + '/spec_helper'

# TODO: 

# Recurrence.new(time, :last => :day, :in  => :month)
# Recurrence.new(:monday, :every_third => :week)

describe Recurrence do
  def recur_on(date)
    # TODO: replace this with more heavy-weight custom matcher which results in more informative
    # failure messages
    simple_matcher("recurrence to recur on #{date}") { |obj| obj.recurs_on?(date) == true }
  end
  
  describe 'initialization' do
    it "should accept a Time object" do
      Recurrence.new(Time.local(2008, 8, 27), :every => :day)
    end

    it "should accept Time.local style argument list" do
      Recurrence.new([2008, 8, 27], :every => :day).recur_from.should == Time.local(2008, 8, 27)
    end

    it "should accept a time string" do
      Recurrence.new('2008-08-27', :every => :day).recur_from.should == Time.local(2008, 8, 27)
    end
    
    it "should accept the symbol epoch" do
      Recurrence.new(:epoch, :every => :day).recur_from.should == Time.local(1970, 1, 1)
    end
  end

  it "should return initialization time" do
    r = Recurrence.new([2008, 8, 27], :every => :day)
    r.recur_from.should == Time.local(2008, 8, 27)
  end

  it "should allow time string argument for recurs_on?" do
    r = Recurrence.new('2008-08-27', :every => :day)
    r.should recur_on('2008-08-30')
  end
  
  it "should return starting date of week" do
    r = Recurrence.new([2008, 8, 27], :every => :day)
    r.starting_dow.should == :wednesday
  end
  
  it "should return starting date of week in short form" do
    r = Recurrence.new([2008, 8, 27], :every => :day)
    r.starting_dow(:short).should == :wed
  end

  describe "recurring every <interval>" do
    it "should not recur before initial date" do
      Recurrence.new('2008-08-27', :every => :day).should_not recur_on('2008-08-26')
    end

    it "should not recur after final date" do
      Recurrence.new('2008-08-27', :every => :day, :until => '2008-10-1').should_not recur_on('2008-10-2')
    end

    it "should recur daily" do
      r = Recurrence.new([2008, 9, 2], :every => :day)

      (2..30).each do |day|
        t = Time.local(2008, 9, day)
        r.should recur_on(t)
      end
    end
    
    it "should recur ad infinitum if until is not specified (well, 2038-01-20 is the day Time instances go boink unless fixed)" do
      Recurrence.new(:epoch, :every => :day).should recur_on('2038-01-19')
    end

    it "should recur weekly" do
      r = Recurrence.new(Time.local(2008, 8, 1), :every => :week)

      (2..7).each do |day|
        r.should_not recur_on(Time.local(2008, 8, day))
      end
      r.should recur_on(Time.local(2008, 8, 8))
    end

    it "should recur monthly" do
      r = Recurrence.new(Time.local(2008, 8, 24), :every => :month)

      (1..23).each do |day|
        r.should_not recur_on(Time.local(2008, 9, day))
      end
      r.should recur_on(Time.local(2008, 9, 24))
    end

    it "should recur yearly" do
      r = Recurrence.new(Time.local(2008, 8, 13), :every => :year)

      (1..31).each do |day|
        r.should_not recur_on(Time.local(2009, 1, day))
      end
      r.should recur_on(Time.local(2009, 8, 13))
    end    
    
    it "should recur every weekend" do
      r = Recurrence.new(:epoch, :every => :weekend)

      (2..3).each do |day| # saturday, sunday
        r.should recur_on(Time.local(2008, 8, day))
      end
      (4..8).each do |day|
        r.should_not recur_on(Time.local(2008, 8, day))
      end
    end
    
    it "should recur every workday" do
      r = Recurrence.new(:epoch, :every => :workday)

      (2..3).each do |day|
        r.should_not recur_on(Time.local(2008, 8, day))
      end
      (4..8).each do |day|
        r.should recur_on(Time.local(2008, 8, day))
      end
    end
    
    it "should raise ArgumentError when given invalid repeat type" do
      lambda { Recurrence.new(Time.local(2008, 8, 22), :foo => :workday) }.should raise_error(ArgumentError)
    end
    
    it "should raise ArgumentError when given invalid recurrence type" do
      lambda { Recurrence.new(Time.local(2008, 8, 22), :every => :homersimpson) }.should raise_error(ArgumentError)
    end
    
  end
  
  describe "recurring every_other <interval>" do
    it "should recur every second day" do
      year, month = 2008, 8
      r = Recurrence.new(Time.local(year, month, 1), :every_other => :day)

      [1, 3, 5, 7, 9, 23].each { |day| r.should recur_on(Time.local(year, month, day)) }
      [2, 4, 8, 10, 12, 26].each { |day| r.should_not recur_on(Time.local(year, month, day)) }
    end
    
    it "should recur every other week" do
      year, month = 2008, 8
      r = Recurrence.new(Time.local(year, month, 2), :every_other => :week)
      
      (3..15).each { |day| r.should_not recur_on(Time.local(year, month, day)) }
      [16, 30].each { |day| r.should recur_on(Time.local(year, month, day)) }
    end
    
    it "should recur every other month" do
      year, month, day = 2008, 1, 1
      r = Recurrence.new(Time.local(year, month, 1), :every_other => :month)
      
      [2, 4, 6].each { |m| r.should_not recur_on(Time.local(year, m, day)) }
      [1, 3, 5].each { |m| r.should recur_on(Time.local(year, m, day)) }
    end
    
    it "should recur every other year" do
      month, day = 4, 29
      r = Recurrence.new(Time.local(2000, month, day), :every_other => :year)
      
      [2005, 2007, 2009].each { |y| r.should_not recur_on(Time.local(y, month, day)) }
      [2006, 2004, 2010].each { |y| r.should recur_on(Time.local(y, month, day)) }
    end
  end
  
  describe "recurring every_third <interval>" do    
    it "should recur every third day" do
      year, month = 2008, 8
      r = Recurrence.new(Time.local(year, month, 8), :every_third => :day)

      [8, 11, 14, 17, 20].each { |day| r.should recur_on(Time.local(year, month, day)) }
      [9, 10, 12, 13, 15, 16, 18, 19].each { |day| r.should_not recur_on(Time.local(year, month, day)) }
    end

    it "should recur every third week" do
      year, month = 2008, 8
      r = Recurrence.new(Time.local(year, month, 1), :every_third => :week)

      (2..21).each { |day| r.should_not recur_on(Time.local(year, month, day)) }
      r.should recur_on(Time.local(year, month, 22))
    end

    it "should recur every third month" do
      year, day = 2008, 1
      r = Recurrence.new(Time.local(year, 1, day), :every_third => :month)

      [1, 4, 7, 10].each { |m| r.should recur_on(Time.local(year, m, day)) }
      [2, 3, 5, 6, 8, 9].each { |m| r.should_not recur_on(Time.local(year, m, day)) }
    end

    it "should recur every third year" do
      month, day = 9, 21
      r = Recurrence.new(Time.local(2001, month, day), :every_third => :year)

      [2004, 2007, 2010].each { |y| r.should recur_on(Time.local(y, month, day)) }
      [2002, 2005, 2006].each { |y| r.should_not recur_on(Time.local(y, month, day)) }
    end
  end
  
  describe "recurring every 10th <interval>" do    
    it "should recur every 10th day" do 
      year, month = 2008, 1
      r = Recurrence.new([year, month, 1], :every_nth => :day, :interval => 10)

      [11, 21, 31].each do |d|
        r.should recur_on([year, month, d])
      end
      
      (2..10).each { |d| r.should_not recur_on([year, month, d]) }
    end

    it "should recur every 10th month" do 
      year, day = 2008, 28
      r = Recurrence.new([year, 1, day], :every_nth => :month, :interval => 10)

      [1, 11].each { |m| r.should recur_on([year, m, day]) }
      
      (2..10).each { |m| r.should_not recur_on([year, m, day]) }
    end
  end
  
  describe "set operations"  do
    it "should be able to form union (OR) of two recurrences" do
      #  1  2  3  4  5  6  7  8  9 10   
      #  |     |     |     |     |     # recur every other day since first

      #  1  2  3  4  5  6  7  8  9 10   
      #  |        |        |        |  # recur every third day since first

      #  1  2  3  4  5  6  7  8  9 10   
      #  |     |  |  |     |     |  |  # union of recurrences above
      start_date = '2008-08-01'
      r = Recurrence.new(start_date, :every_other => :day).join(Recurrence.new(start_date, :every_third => :day))
      [1, 3, 4, 5, 7, 9, 10].each { |d| r.should recur_on([2008, 8, d]) }
    end
        
    it "should be able to form intersection (AND) of two recurrences" do
      #  1  2  3  4  5  6  7  8  9 10   
      #  |     |     |     |     |     # recur every other day since first

      #  1  2  3  4  5  6  7  8  9 10   
      #  |        |        |        |  # recur every third day since first

      #  1  2  3  4  5  6  7  8  9 10   
      #  |                 |           # intersection of recurrences above
      start_date = '2008-08-01'
      r = Recurrence.new(start_date, :every_other => :day).intersect(Recurrence.new(start_date, :every_third => :day))
      [1, 7].each { |d| r.should recur_on(Time.local(2008, 8, d)) }
    end
    
    it "should be able to form difference (\) of two recurrences" do
      #  1  2  3  4  5  6  7  8  9 10   
      #  |     |     |     |     |     # recur every other day since first

      #  1  2  3  4  5  6  7  8  9 10   
      #  |        |        |        |  # recur every third day since first

      #  1  2  3  4  5  6  7  8  9 10   
      #        |     |           |     # difference of recurrences above

      start_date = '2008-08-01'
      r = Recurrence.new(start_date, :every_other => :day).diff(Recurrence.new(start_date, :every_third => :day))
      [3, 5, 9].each { |d| r.should recur_on([2008, 8, d]) }
      [1, 2, 4, 6, 7, 8].each { |d| r.should_not recur_on([2008, 8, d]) }
    end
    
    it "should be able to form complement (NOT) of a recurrence" do
      r = Recurrence.new('2008-08-01', :every_other => :day).complement
      orig = r.complement

      [2, 4, 6, 8, 10].each { |day| 
        date = Time.local(2008, 8, day)
        r.should recur_on(date)
        orig.should_not recur_on(date)
      }

      [1, 3, 5, 7, 9].each { |day|
        date = Time.local(2008, 8, day)
        r.should_not recur_on(date) 
        orig.should recur_on(date)
      }
    end
    
    it "should be able to support nested set-like operations" do
      #  1  2  3  4  5  6  7  8  9 10   
      #  |     |     |     |     |     # recur every other day since first

      #  1  2  3  4  5  6  7  8  9 10   
      #  |        |        |        |  # recur every third day since first

      #  1  2  3  4  5  6  7  8  9 10   
      #     !           |     |        # complement of (A union B) == (NOT A) AND (NOT B)
      
      start_date = '2008-01-01'
      a = Recurrence.new(start_date, :every_other => :day)
      b = Recurrence.new(start_date, :every_third => :day)

      # De Morgan's
      complement_of_union = (a.join(b)).complement
      intersection_of_complements = (a.complement).intersect(b.complement)
      
      
      [2, 6, 8].each { |d| 
        date = [2008, 1, d]
        complement_of_union.should recur_on(date)
        intersection_of_complements.should recur_on(date)
      }
      [1, 3, 4, 5, 7, 9, 10].each { |d| 
        date = [2008, 1, d]
        complement_of_union.should_not recur_on(date)
        intersection_of_complements.should_not recur_on(date)
      }
    end
  end
  
  describe "recurring every nth of <weekday> of a <period>" do
    it "should recur every first thursday of a month" do
      r = Recurrence.new(:epoch, :every_first => :thursday, :of => :month)
      (1..30).each { |day|  
        # 4th day is the first thursday on Sep 2008
        date = [2008, 9, day]
        if day == 4
          r.should recur_on(date)
        else
          r.should_not recur_on(date)
        end
      }
    end
    
    it "should recur every second thursday of a month" do
      r = Recurrence.new(:epoch, :every_second => :thursday, :of => :month)
      (1..30).each { |day|  
        # 11th day is second thursday on Sep 2008
        date = [2008, 9, day]
        if day == 11
          r.should recur_on(date)
        else
          r.should_not recur_on(date)
        end
      }
    end
    
    it "should recur every last thursday of a month" do
      r = Recurrence.new(:epoch, :every_last => :thursday, :of => :month)
      (1..30).each { |day|  
        # 25th day is the last thursday on Sep 2008
        date = [2008, 9, day]
        if day == 25
          r.should recur_on(date)
        else
          r.should_not recur_on(date)
        end
      }
    end
  end
  
  it "should yield every other day" do
    r = Recurrence.new(:epoch, :every_other => :day)
    days = []
    
    r.each {|t|
      break if t.day > 5
      days << t.day
    }
    days.should == [1, 3, 5]
  end

  it "should yield every week" do
    r = Recurrence.new(:epoch, :every => :week)
    weekdays = []
    
    r.each {|t|
      weekdays << t.wday
      break if weekdays.length > 3
    }
    weekdays.should == [r.recur_from.wday] * 4
  end
  
  it "should yield every month, setting the date to last in month if overlapping" do
    r = Recurrence.new('2008-01-31', :every => :month)
    days_months = []
    
    r.each {|t|
      break if days_months.length > 3
      days_months << [t.day, t.mon]
    }
    days_months.should == [[31, 1], [29, 2], [31, 3], [30,4]]
  end
  
end
