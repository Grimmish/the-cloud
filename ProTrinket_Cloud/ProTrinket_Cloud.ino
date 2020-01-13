/*
* Cloud!
*/
#include <FastLED.h>

/*
	Terms:
		activity: 0-255 scale of current Determines color saturation level.
		fade: Time-based deterioration of activity. One point is deducted
		      every `fade` milliseconds
*/
		
#define PIR_SENSOR 9
#define NUM_LEDS 4

#define DEBUGMODE 0

// 8-bit scale (0-255)
uint8_t activity = 40; // Initial value

// Increase to apply to 'activity' when motion sensor fires
#define ACTIVITY_BUMP 35

// Delay (in ms) between -1 decrements to 'activity'
#define ACTIVITY_FADE_MS 7000 // About 30 minutes to fade from max to min

// 8-bit color wheel rotates by 1 at this interval (ms)
#define CYCLEDELAY 10

/** END OF CONFIG SECTION **/

CRGB leds[NUM_LEDS];
unsigned long int lastfade;
unsigned long int lastshift;
uint8_t pir_state = 0;
uint8_t hue = 0;

void setup() {
  pinMode(PIR_SENSOR, INPUT);
  FastLED.addLeds<APA102, 11, 13, BGR>(leds, NUM_LEDS);
  pir_state = digitalRead(PIR_SENSOR);
  lastfade = millis();
}

void loop() {
  if (DEBUGMODE) {
    // PIR input test
    if (digitalRead(PIR_SENSOR)) {
      for (int x=0; x<NUM_LEDS; x++) {
        leds[x] = CRGB::Red;
      }
    }
    else {
      for (int x=0; x<NUM_LEDS; x++) {
        leds[x] = CRGB::Black;
      }
    }
    FastLED.show();
  }
  else {
    // Motion == apply activity bump (with ceiling of 255)
    if (pir_state != digitalRead(PIR_SENSOR)) {
      pir_state = digitalRead(PIR_SENSOR);
      if (pir_state) {
        if (activity + ACTIVITY_BUMP > 255) {
          activity = 255;
        }
        else {
          activity += ACTIVITY_BUMP;
        }
      }
    }
  
    // Slow rainbow cycle - saturation determined by activity
    leds[0] = CHSV( hue, activity, 128+(activity/2) );
    leds[1] = CHSV( hue+64, activity, 128+(activity/2) );
    leds[2] = CHSV( hue+128, activity, 128+(activity/2) );
    leds[3] = CHSV( hue+192, activity, 128+(activity/2) );
    FastLED.show();
    hue++;
    delay(CYCLEDELAY);
  
    if (millis() - lastfade > ACTIVITY_FADE_MS) {
      if (activity > 0) {
        activity -= 1;
      }
      lastfade = millis();
    }
  }


}
