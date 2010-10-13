require 'net/http'
require 'rubygems'
require 'uuid'
require 'rexml/document'
require 'rexml/xpath'
require 'date'

class Event
    attr_accessor :uid, :created, :dtstart, :dtend, :lastmodified, :summary
end

class Todo
    attr_accessor :uid, :created, :summary, :dtstart, :status, :completed, :description
end

class Calendar
  attr_accessor :path, :name
end

class CalendarsCollection < Array
  def []( name )
    select { | cal | cal.name.downcase == name }
  end
end

module Net
    class HTTP
        class Report < HTTPRequest
            METHOD = 'REPORT'
            REQUEST_HAS_BODY = true
            RESPONSE_HAS_BODY = true
        end
    end
end

class Caldav
    CALDAV_NAMESPACE = "urn:ietf:params:xml:ns:caldav"
    TIME_FORMAT = '%Y%m%dT%H%M%SZ'
    attr_accessor :host, :port, :url, :user, :password

    def initialize( host, port, url, user, password )
       @host = host
       @port = port
       @url = url
       @user = user
       @password = password 
    end

    def report calendar, range
        dings = """<?xml version='1.0'?>
<c:calendar-query xmlns:c='#{CALDAV_NAMESPACE}'>
  <d:prop xmlns:d='DAV:'>
    <d:getetag/>
    <c:calendar-data>
    </c:calendar-data>
  </d:prop>
  <c:filter>
    <c:comp-filter name='VCALENDAR'>
      <c:comp-filter name='VEVENT'>
        <c:time-range start='#{range.begin.strftime(TIME_FORMAT)}' end='#{range.end.strftime(TIME_FORMAT)}'/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>
"""
        res = nil
        http = Net::HTTP.new(@host, @port)
#        http.set_debug_output $stderr

        #Net::HTTP.start(@host, @port) {|http|
        http.start {|http|

            req = Net::HTTP::Report.new(calendar.path, initheader = {'Content-Type'=>'application/xml'} )
            req.basic_auth @user, @password
            req.body = dings


            res = http.request( req )
        }
        result = []
        xml = REXML::Document.new( res.body )
        REXML::XPath.each( xml, '//c:calendar-data/', { "c"=>CALDAV_NAMESPACE} ){ |c|
            result <<  parseVcal( c.text )
        }
        return result
    end
    
    def get uuid
        res = nil
        Net::HTTP.start( @host, @port ) {|http|
            req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
            req.basic_auth @user, @password
            res = http.request( req )
        }
        return parseVcal( res.body )
    end

    def delete uuid
        Net::HTTP.start(@host, @port) {|http|
            req = Net::HTTP::Delete.new("#{@url}/#{uuid}.ics")
            req.basic_auth @user, @password
            res = http.request( req )
        }
    end

    def create event
        now = DateTime.now 
        uuid =  UUID.new

        dings = """BEGIN:VCALENDAR
PRODID:Caldav.rb
VERSION:2.0

BEGIN:VTIMEZONE
TZID:/Europe/Vienna
X-LIC-LOCATION:Europe/Vienna
BEGIN:DAYLIGHT
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
TZNAME:CEST
DTSTART:19700329T020000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
TZNAME:CET
DTSTART:19701025T030000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10
END:STANDARD
END:VTIMEZONE

BEGIN:VEVENT
CREATED:#{now.strftime(TIME_FORMAT)}
UID:#{uuid}
SUMMARY:#{event.summary}
DTSTART;TZID=Europe/Vienna:#{event.dtstart.strftime(TIME_FORMAT)}
DTEND;TZID=Europe/Vienna:#{event.dtend.strftime(TIME_FORMAT)}
END:VEVENT
END:VCALENDAR"""


        res = nil
        Net::HTTP.start(@host, @port) {|http|
            req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics", initheader = {'Content-Type'=>'text/calendar'} )
            req.basic_auth @user, @passowrd
            req.body = dings
            res = http.request( req )
        }
        return uuid
    end

    def update event
        dings = """BEGIN:VCALENDAR
PRODID:Caldav.rb
VERSION:2.0

BEGIN:VTIMEZONE
TZID:/Europe/Vienna
X-LIC-LOCATION:Europe/Vienna
BEGIN:DAYLIGHT
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
TZNAME:CEST
DTSTART:19700329T020000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
TZNAME:CET
DTSTART:19701025T030000
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10
END:STANDARD
END:VTIMEZONE

BEGIN:VEVENT
CREATED:#{event.created.strftime(TIME_FORMAT)}
UID:#{event.uid}
SUMMARY:#{event.summary}
DTSTART;TZID=Europe/Vienna:#{event.dtstart.strftime(TIME_FORMAT)}
DTEND;TZID=Europe/Vienna:#{event.dtend.strftime(TIME_FORMAT)}
END:VEVENT
END:VCALENDAR"""

        res = nil
        Net::HTTP.start(@host, @port) {|http|
            req = Net::HTTP::Put.new("#{@url}/#{event.uid}.ics", initheader = {'Content-Type'=>'text/calendar'} )
            req.basic_auth @user, @passowrd
            req.body = dings
            res = http.request( req )
        }
        return event.uid
    end

    def todo calendar
        dings = """<?xml version='1.0'?>
<c:calendar-query xmlns:c='#{CALDAV_NAMESPACE}'>
  <d:prop xmlns:d='DAV:'>
    <d:getetag/>
    <c:calendar-data>
    </c:calendar-data>
  </d:prop>
  <c:filter>
    <c:comp-filter name='VCALENDAR'>
      <c:comp-filter name='VTODO'>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>
"""
        res = nil
        Net::HTTP.start(@host, @port) {|http|
            req = Net::HTTP::Report.new(calendar.path, initheader = {'Content-Type'=>'application/xml'} )
            req.basic_auth @user, @password
            req.body = dings
            res = http.request( req )
        }
        result = []
        xml = REXML::Document.new( res.body )
        REXML::XPath.each( xml, '//c:calendar-data', { "c"=>CALDAV_NAMESPACE} ){ |c|
            result << parseVcal( c.text )
        }
        return result
    end

    def calendars
      dings = """<?xml version='1.0'?>
<d:propfind xmlns:d='DAV:' xmlns:c='#{CALDAV_NAMESPACE}'>
<d:prop>
<c:calendar-free-busy-set/>
<d:displayname/>
<d:resourcetype/>
</d:prop>
</d:propfind>
"""
      res = nil
      Net::HTTP.start(@host, @port) do | http |
          req = Net::HTTP::Propfind.new(@url, initheader = {'Content-Type'=>'application/xml'} )
          req.basic_auth @user, @password
          req['DEPTH'] = 1
          req.body = dings
          res = http.request( req )
      end
      result = CalendarsCollection.new
      xml = REXML::Document.new( res.body )
      REXML::XPath.each( xml, "//[*/*/*/c:calendar]", {'c' => CALDAV_NAMESPACE} ) do | c |
        href = c.elements['href'].text
        display_name = c.elements['propstat/prop/displayname'].text
        calendar = Calendar.new
        calendar.path = href
        calendar.name = display_name
        result << calendar
      end
      result
    end

    def parseVcal( vcal )
      if vcal.index( "VEVENT" ) then
        e = Event.new
        data = filterTimezone( vcal )
      elsif( vcal.index( 'VTODO' ) ) then
        data = vcal
        e = Todo.new
      end
      data.split("\n").each do |l|
        case( l )
          when /UID/
            e.uid = getField( "UID", l)
          when /CREATED/
            e.created = Time.parse(getField( "CREATED", l))
          when /DTSTART/
            e.dtstart = Time.parse(getField( "DTSTART", l))
          when /DTEND/
            e.dtend = Time.parse(getField( "DTEND", l))
          when /LAST-MODIFIED/
            e.lastmodified = Time.parse(getField( "LAST-MODIFIED", l))
          when /SUMMARY/
            e.summary = getField( "SUMMARY", l)
          when /STATUS/
            e.status = getField( "STATUS", l)
          when /COMPLETED/
            e.completed = Time.parse(getField( "COMPLETED", l))
          when /DESCRIPTION/
            e.description = getField( "DESCRIPTION", l)
        end
      end
      e
    end
    
    def filterTimezone( vcal )
        data = ""
        inTZ = false
        vcal.split("\n").each{ |l| 
            inTZ = true if l.index("BEGIN:VTIMEZONE") 
            data << l+"\n" unless inTZ 
            inTZ = false if l.index("END:VTIMEZONE") 
        }
        return data
    end

    def getField( name, l )
        fname = (name[-1] == ':'[0]) ? name[0..-2] : name 
        return NIL unless l.index(fname)
        idx = l.index( ":", l.index(fname))
        return l[ idx+1..-1 ] 
    end
end
