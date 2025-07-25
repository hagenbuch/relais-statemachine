# relais-statemachine

This code is Berry script code for an ESP32 on a waveshare device (see below) with Tasmota-esp32s3 15.0.1.

However, buttons and LEDs have been added via I2C bus and a PCF8574 port expander:

By pressing four buttons with color red, yellow, green and blue, four corresponding ventilators are being activated via relais.

While the button serve a toggle buttons, every active channel runs into a timeout.

A fifth channel controls a pump, the pump is also being activated by any button press but it runs a little longer.

In addition, a LED RGB strip can be controlled via various presets, depending on the buttons pressed or timeout run into.

Different from what I thought, this is not really a state machine any more.

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
      Device IP: <redacted>
    WLED device: https://www.gledopto.eu/gledopto-gl-dr-009wl-hutschienen-controller
     Vendor URL: https://www.gledopto.eu/gledopto-gl-dr-009wl-hutschienen-controller
           Cost: 24,99 EUR (2025)
       Software: WLED
        Version: 0.15.0
            URL: https://kno.wled.ge/
      Device IP: <redacted>

       Filename: hscf.be
      Called by: autoexec.be
        Purpose: Main loop controls five timers, six relais and WLED device via JSOn over http.

Necessary compiler options to include PCF8574 functionality:

    #ifndef USE_I2C
    #define USE_I2C                              // I2C using library wire (+10k code, 0k2 mem, 124 iram)
    #endif

    #define USE_PCF8574                          // [I2cDriver2] Enable PCF8574 I/O Expander (I2C addresses 0x20 - 0x26 and 0x39 - 0x3F) (+1k9 code)
    #define USE_PCF8574_SENSOR                   // enable PCF8574 inputs and outputs in SENSOR message
    #define USE_PCF8574_DISPLAYINPUT             // enable PCF8574 inputs display in Web page
    #define USE_PCF8574_MQTTINPUT                // enable MQTT message & rule process on input change detection : 
                                                 // stat/%topic%/PCF8574_INP = {"Time":"2021-03-07T16:19:23+01:00","PCF8574-1_INP":{"D1":1}}

