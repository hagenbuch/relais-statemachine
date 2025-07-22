#-------------------------------------------------------

Description: Berry script
       Date: 20250226
   Modified: 20250709
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
    Version: 14.5.0
   Language: Berry script
  Device IP: 192.168.138.24
WLED device: https://www.gledopto.eu/gledopto-gl-dr-009wl-hutschienen-controller
 Vendor URL: https://www.gledopto.eu/gledopto-gl-dr-009wl-hutschienen-controller
       Cost: 24,99 EUR
   Software: WLED
    Version: 0.15.0
        URL: https://kno.wled.ge/
  Device IP: 192.168.138.51

   Filename: hscf.be
  Called by: autoexec.be
    Purpose: Main loop with state machine:
             
             Turns ventilators and a water pump on an odd randomly to simulate 
             weather in a landscape model with a model lake

             RGB LED and RS485 port are available!

             With an additional "hat", two luminosity sensors are connected via I2C
             so the logic run only some minutes after activation

 -------------------------------------------------------#

# ----- Configuration section -----

# Relay hardware GPIOs:
     RELAYS = [1, 2, 41, 42, 45, 46]
RELAYLABELS = ["Lüfter Südwest", "Lüfter Südost", "Lüfter Nordost", "Lüfter Nordwest", "Pumpen", "Reserve"]

# WLED commends to set presets of the LED commander
   WLED_URL = "http://192.168.22.126/json/state"
   WLED_PS1 = '{"on":"true","bri":128,"ps":1}'
   WLED_PS2 = '{"on":"true","bri":128,"ps":2}'
   WLED_PS3 = '{"on":"true","bri":128,"ps":3}'
   WLED_PS4 = '{"on":"true","bri":128,"ps":4}'

# Switch numbers:
     FAN_SW = 0 # Switch / relay 1
     FAN_SO = 1
     FAN_NO = 2
     FAN_NW = 3
      PUMPS = 4
      SPARE = 5 # Switch / relay 6

# Settings
     SLEEPCYCLES = 100  
        PLAYTIME = 180000 # 3 minutes

# Schedules - Use CET, not CEST
    PLAYSCHEDULE = {
       'start':'6:30', 
       'end':'20:00'
    }

           DEBUG = true

print('   booting hscf.be')

# ---- Do not change below this line ----
import math
import string
import json

var ON = true
var OFF = false

var state = 0
var sleepcounter = 0
var playtimer = 0
var steptimer = 0
var first_left_fan = 0
var first_right_fan = 0
var second_left_fan = 0
var second_right_fan = 0
var r = 0
var ra = 0

var light_red = {'power':true, 'rgb':'FF0000', 'bri':128}
var light_blue = {'power':true, 'rgb':'0000FF', 'bri':128}
var light_green = {'power':true, 'rgb':'00FF00', 'bri':128}
var light_yellow = {'power':true, 'rgb':'FFFF00', 'bri':128}
var light_off = {'power':false, 'rgb':'000000', 'bri':128}
var light_white = {'power':true, 'rgb':'FFFFFF', 'bri':128}

# Initialization
tasmota.set_power(FAN_SW, OFF) # Channel 1
tasmota.set_power(FAN_SO, OFF) # Channel 2
tasmota.set_power(FAN_NO, OFF) # Channel 3
tasmota.set_power(FAN_NW, OFF) # Channel 4
tasmota.set_power(PUMPS, OFF) # Channel 5
tasmota.set_power(SPARE, OFF) # Channel 6, unused

def nextrandomstep(duration, randomduration)
    assert(duration > 0, 'duration must be greater 0')
    assert(randomduration > 0, 'randomduration must be greater 0')
    return tasmota.millis() + duration + math.rand() % randomduration
end    

def httppost(url, action)
    var wc = webclient()
    wc.begin(url) 
    var wcstat = wc.POST(action)
    print("POST return: " + str(wcstat))
    var response = wc.get_string()
    print("POST response: " + response)
    wc.close()
    return response
end

light.set(light_blue)
print("  light: blue")
#httppost(WLED_URL, WLED_PS1)

# Get the starting and ending minutes of the schedule

var from = string.split(PLAYSCHEDULE['start'], ':')
var frommin = int(from[0]) * 60 + int(from[1])
var to = string.split(PLAYSCHEDULE['end'], ':')
var tomin = int(to[0]) * 60 + int(to[1])

def mainloop()
    var sensors = json.load(tasmota.read_sensors())

    # Night / Idle: Waiting for schedule
    # ----------------------------------
    if state == 0
        var l = tasmota.rtc()['local']
        var t = tasmota.time_dump(l)
        var sfmin = t['hour'] * 60 + t['min']
        var schedule = false
        if sfmin > frommin
            if sfmin < tomin
                schedule = true
            end
        end
        if schedule
            state = 1
            print(string.format('  Schedule ON at: %i minutes', sfmin))
            if DEBUG 
                print("State 0 to 1: Good Morning")
            end
            print("  light: green")
            light.set(light_green)
#            httppost(WLED_URL, WLED_PS2)
        end
    end
    # Day / Wating: Waiting for end of schedule
    # ------------------------------------------
    if state == 1
        # Wait for schedule to end or key pressed
        var l = tasmota.rtc()['local']
        var t = tasmota.time_dump(l)
        var sfmin = t['hour']*60+t['min']
        var schedule = false
        if sfmin > frommin
            if sfmin < tomin
                schedule = true
            end
        end
        if schedule == false
            print(string.format('  Schedule OFF at: %i minutes', sfmin))
            state = 0 # To sleep
            if DEBUG
                print("State 1 to 0: Yawn")
            end
            tasmota.set_power(PUMPS, OFF)
            print("  light: blue")
            light.set(light_blue)
#            httppost(WLED_URL, WLED_PS1)
        else
            state = 2
            r = math.rand() % 2
            first_left_fan = r
            second_left_fan = 1 - r
            if DEBUG
                print("State 1 to 2: start first left fan")
            end
            playtimer = tasmota.millis() + PLAYTIME
            tasmota.set_power(first_left_fan, ON)
            print("  light: yellow")
            light.set(light_yellow)
#            httppost(WLED_URL, WLED_PS3)
        end
    end
    # Play: First left fan started
    # ----------------------------
    if state == 2
        # Is playtime up?
        if playtimer < tasmota.millis()
            playtimer = 0
            # Playtime is up!
            state = 1
            if DEBUG
                print("State 2 to 1: Enough play!")
            end
            tasmota.set_power(FAN_SW, OFF) # Channel 1
            tasmota.set_power(FAN_SO, OFF) # Channel 2
            tasmota.set_power(FAN_NO, OFF) # Channel 3
            tasmota.set_power(FAN_NW, OFF) # Channel 4
            tasmota.set_power(PUMPS, OFF) # Channel 5
        end
     
        # Wait for random time:
        if steptimer == 0
            steptimer = nextrandomstep(3000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                state = 3
                if DEBUG
                    print("State 2 to 3: Start second left fan")
                end
                tasmota.set_power(second_left_fan, ON)
            end
        end

    end
    # Second left fan started
    # -----------------------
    if state == 3
        if steptimer == 0
            steptimer = nextrandomstep(15000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                state = 4
                r = math.rand() % 2
                first_left_fan = r
                second_left_fan = 1 - r
                if DEBUG
                    print("State 3 to 4: Stop first left fan")
                end
                tasmota.set_power(first_left_fan, OFF)
            end
        end
    end
    # First left fan stopped
    # ----------------------
    if state == 4      
        if steptimer == 0
            steptimer = nextrandomstep(3000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                state = 5
                if DEBUG
                    print("State 4 to 5: Stop second left fan")
                end 
                tasmota.set_power(second_left_fan, OFF)
                tasmota.set_power(PUMPS, ON)
            end
        end
    end
    # Second left fan stopped
    # -----------------------
    if state == 5
        if steptimer == 0
            steptimer = nextrandomstep(15000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                state = 6
                r = math.rand() % 2
                first_right_fan = 2 + r
                second_right_fan = 2 + (1 - r)
                if DEBUG
                    print("State 5 to 6: Start first right fan")
                end
                tasmota.set_power(first_right_fan, ON)
            end
        end
    end
    # First right fan started
    # -----------------------
    if state == 6
        if steptimer == 0
            steptimer = nextrandomstep(3000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                state = 7
                if DEBUG
                    print("State 6 to 7: Start second right fan")
                end
                tasmota.set_power(second_right_fan, ON)
            end
        end
    end
    # Second right fan started
    # ------------------------
    if state == 7
        if steptimer == 0
            steptimer = nextrandomstep(5000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                state = 8
                r = math.rand() % 2
                first_right_fan = 2 + r
                second_right_fan = 2 + (1 - r)
                if DEBUG
                    print("State 7 to 8: Stop first right fan")
                end
                tasmota.set_power(first_right_fan, OFF)
            end
        end
    end
    # First right fan stopped
    # -----------------------
    if state == 8
        if steptimer == 0
            steptimer = nextrandomstep(15000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                state = 9
                if DEBUG
                    print("State 8 to 9: Stop second right fan")
                end
                tasmota.set_power(second_right_fan, OFF)
            end
        end
    end
    # Second right fan stopped
    # ------------------------
    if state == 9
        if steptimer == 0
            steptimer = nextrandomstep(15000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                state = 10
                if DEBUG
                    print("State 9 to 10: Wait if cycle ended")
                end
                tasmota.set_power(second_right_fan, OFF)
            end
        end
    end
    # Wait, then wait for playtime to end
    # -------------
    if state == 10
        if steptimer == 0
            steptimer = nextrandomstep(5000, 2000)
        else
            if steptimer < tasmota.millis()
                steptimer = 0
                if DEBUG
                    print(string.format('  Remaining playtime: %i s', (playtimer - tasmota.millis()) / 1000))
                end    
                if playtimer < tasmota.millis()
                    state = 1
                    playtimer = 0
                    if DEBUG
                        print("State 10 to 1: End play")
                    end
                    tasmota.set_power(PUMPS, OFF)
                    print("  light: green")
                    light.set(light_green)
#                    httppost(WLED_URL, WLED_PS2)
                else 
                    state = 2
                    if DEBUG
                        print("State 10 to 2: Continue play")
                    end
                end
            end
        end
    end
end

def set_timer_modulo(delay, f, id)
  # Every delay milliseconds, we'll set a time when to call function f: 
  var now = tasmota.millis()
  tasmota.set_timer((now + delay / 4 + delay) / delay * delay - now, def() set_timer_modulo(delay, f, id) f() end, id)
end

# Enable the clock:
set_timer_modulo(500, mainloop)
