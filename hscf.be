#-------------------------------------------------------

Description: Berry script
       Date: 20250226
   Modified: 20250723
     Author: Andreas Delleske
    Company: https://www.dellekom.de
     Target: Waveshare ESP32S3-Relay-6CH
 Vendor URL: https://www.waveshare.com/esp32-s3-relay-6ch.htm
   URL Wiki: https://www.waveshare.com/wiki/ESP32-S3-Relay-6CH
       Cost: 34,95 EUR (2025)
   Software: Tasmota
        URL: https://github.com/arendst/Tasmota
   Template: {"NAME":"Waveshare-ESP32S3-Relay-6CH",
             "GPIO":[1,224,225,1,1,1,1,1,1,1,1,1,1,1,1,1,1,9408,9440,1,1,
             480,0,0,0,0,0,1376,1,1,226,227,1,1,228,229,1,1],
             "FLAG":0,"BASE":1}
    Version: 15.0.1
   Language: Berry script
  Device IP: 192.168.138.24
WLED device: https://www.gledopto.eu/gledopto-gl-dr-009wl-hutschienen-controller
 Vendor URL: https://www.gledopto.eu/gledopto-gl-dr-009wl-hutschienen-controller
       Cost: 24,99 EUR (2025)
   Software: WLED
    Version: 0.15.0
        URL: https://kno.wled.ge/
  Device IP: 192.168.138.51

   Filename: hscf.be
  Called by: autoexec.be
    Purpose: Main loop with state machine:
             
             0 Idle: Waiting for timer schedule
             1 Ready: Ready to take button presses
             2 Run: Button pressed, timers are activated 

 -------------------------------------------------------#
# ----- Configuration section -----

# Relay hardware GPIOs:
     RELAYS = [1, 2, 41, 42, 45, 46]
RELAYLABELS = ["Lüfter Südwest", "Lüfter Südost", "Lüfter Nordost", "Lüfter Nordwest", "Pumpen", "Reserve"]
    BUTTONS = ["D4", "D5", "D6", "D7"]
 BUTTONCLRS = ["red", "yellow", "green", "blue"]
       LEDS = [6, 7, 8, 9]
       FANS = [0, 1, 2, 3]

# WLED commends to set presets of the LED commander
   WLED_URL = "http://192.168.13.133/json/state"
   WLED_JSON = '{"on":true,"ps":%i}'

# Relay numbers:
     FAN_SW = 0 # Switch / relay 1
     FAN_SO = 1
     FAN_NO = 2
     FAN_NW = 3
      PUMPS = 4
      SPARE = 5 # Switch / relay 6

# PDF8547 digital interface extension
# I2C address: 0x20
# Name: PCF8574-1

# Settings
        PLAYTIME = 180000 # 3 minutes
      BUTTONTIME = 30000 # 10 seconds

# Schedules - Use CET, not CEST
    PLAYSCHEDULE = {
       'start':'6:00', 
       'end':'21:00'
    }

DEBUG = true

# ---- Do not change below this line ----
import math
import string
import json

var ON = true
var OFF = false

var state = 0
var playtimer = 0

var light_red = {'power':true, 'rgb':'FF0000', 'bri':128}
var light_blue = {'power':true, 'rgb':'0000FF', 'bri':128}
var light_green = {'power':true, 'rgb':'00FF00', 'bri':128}
var light_yellow = {'power':true, 'rgb':'FFFF00', 'bri':128}
var light_off = {'power':false, 'rgb':'000000', 'bri':128}
var light_white = {'power':true, 'rgb':'FFFFFF', 'bri':128}

var buttonstate = [1, 1, 1, 1, 1]     # inverted, 0 = active
var buttonlaststate = [1, 1, 1, 1, 1] # inverted, 0 = active
var timermillis = [0, 0, 0, 0, 0]

# Initialization
tasmota.set_power(FAN_SW, OFF) # Channel 1
tasmota.set_power(FAN_SO, OFF) # Channel 2
tasmota.set_power(FAN_NO, OFF) # Channel 3
tasmota.set_power(FAN_NW, OFF) # Channel 4
tasmota.set_power(PUMPS, OFF) # Channel 5
tasmota.set_power(SPARE, OFF) # Channel 6, unused

def dash()
    for i:6..9
        tasmota.set_power(i, ON)
        tasmota.set_power(i, OFF)
    end
end

dash()

def httppost(url, json_payload, i)
    var wc = webclient()
    wc.begin(url)
    wc.add_header("Content-Type", "application/json")  # Set JSON content type
    var wcstat = wc.POST(string.format(json_payload, i))  # Send POST with payload
    print("POST return: " + str(wcstat))
    var response = wc.get_string()
    print("POST response: " + response)
    wc.close()
    return response
end

def nextrandomstep(duration, randomduration)
    assert(duration > 0, 'duration must be greater 0')
    assert(randomduration > 0, 'randomduration must be greater 0')
    return tasmota.millis() + duration + math.rand() % randomduration
end    

# Get the starting and ending minutes of the schedule

var from = string.split(PLAYSCHEDULE['start'], ':')
var frommin = int(from[0]) * 60 + int(from[1])
var to = string.split(PLAYSCHEDULE['end'], ':')
var tomin = int(to[0]) * 60 + int(to[1])


def mainloop()
    var sensors = json.load(tasmota.read_sensors())
    var inputs = sensors['PCF8574-1']
    var trigger = false

    var l = tasmota.rtc()['local']
    var t = tasmota.time_dump(l)
    var sfmin = t['hour'] * 60 + t['min']
    var enable = false
    if sfmin > frommin
        if sfmin < tomin
            enable = true
        end
    end

    for i:0..3
        var buttonaddr = BUTTONS[i] 
        buttonstate[i] = inputs[buttonaddr]

        if buttonstate[i] != buttonlaststate[i]
            # button edge detection:
            if buttonstate[i] == 0
                # button has been pressed:
                if timermillis[i] == 0
                    # start timer:
                    if enable 
                        trigger = true
                        timermillis[i] = tasmota.millis() + BUTTONTIME
                        tasmota.set_power(LEDS[i], ON)
                        tasmota.set_power(FANS[i], ON)
                        httppost(WLED_URL, WLED_JSON, i + 1)
                        print(string.format('     Button %s %s: ON', buttonaddr, BUTTONCLRS[i]))
                    else
                        dash()
                    end
                else 
                    # stop timer:
                    timermillis[i] = 0
                    tasmota.set_power(LEDS[i], OFF)
                    tasmota.set_power(FANS[i], OFF)
                    print(string.format('     Button %s %s: OFF', buttonaddr, BUTTONCLRS[i]))
                end
            end
            buttonlaststate[i] = buttonstate[i]
        end
        if timermillis[i] != 0
            if timermillis[i] < tasmota.millis()
                timermillis[i] = 0
                tasmota.set_power(LEDS[i], OFF)
                tasmota.set_power(FANS[i], OFF)
                httppost(WLED_URL, WLED_JSON, 5)
                print(string.format('     Timeout %s %s: OFF', buttonaddr, BUTTONCLRS[i]))
            end
        end
    end # for
    if trigger
        playtimer = tasmota.millis() + PLAYTIME
        tasmota.set_power(PUMPS, ON)
    end
    if playtimer != 0
        if playtimer < tasmota.millis()
            playtimer = 0
            tasmota.set_power(PUMPS, OFF)
            httppost(WLED_URL, WLED_JSON, 6)
        end
    end

end # main loop

def set_timer_modulo(delay, f, id)
  # Every delay milliseconds, we'll set a time when to call function f: 
  var now = tasmota.millis()
  tasmota.set_timer((now + delay / 4 + delay) / delay * delay - now, def() set_timer_modulo(delay, f, id) f() end, id)
end

# Enable the clock:
set_timer_modulo(200, mainloop)
