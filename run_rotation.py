import pyautogui
import time
import sys
import os
import ctypes
import winsound

# Key Mapping matching the Lua Addon
# Red    (255, 0, 0)     -> '1' (Haunt)
# Green  (0, 255, 0)     -> '2' (Unstable Affliction)
# Blue   (0, 0, 255)     -> '3' (Corruption)
# Yellow (255, 255, 0)   -> '4' (Curse of Agony)
# Purple (255, 0, 255)   -> '5' (Shadow Bolt)
# White  (255, 255, 255) -> '6' (Drain Soul)
# Cyan   (0, 255, 255)   -> '7' (Life Tap)

KEYS = {
    (255, 0, 0): '1',
    (0, 255, 0): '2',
    (0, 0, 255): '3',
    (255, 255, 0): '4',
    (255, 0, 255): '5',
    (255, 255, 255): '6',
    (0, 255, 255): '7',
    (255, 128, 0): '8',
    (255, 105, 180): '9',
    (0, 128, 128): '0',
    (128, 0, 0): 'z',
    (139, 69, 19): 'g',
    (0, 0, 128): 'f',
    (75, 0, 130): 'y',
    (100, 149, 237): 'q',
    (50, 205, 50): 'i'
}

TOLERANCE = 30
PAUSED = True

# Windows Virtual Key Codes
VK_X = 0x58 # Pause/Resume (Key X)
VK_F12 = 0x7B # Exit

def is_key_pressed(vk_code):
    return ctypes.windll.user32.GetAsyncKeyState(vk_code) & 0x8000

def match_color(pixel, target_rgb):
    r, g, b = pixel
    tr, tg, tb = target_rgb
    return (abs(r - tr) < TOLERANCE and 
            abs(g - tg) < TOLERANCE and 
            abs(b - tb) < TOLERANCE)

def main():
    global PAUSED
    print("=========================================")
    print("   Frostmourne Rotation Bot (PQR-like)   ")
    print("=========================================")
    print("Instructions:")
    print("X Key: PAUSE / RESUME")
    print("F12: QUIT")
    print("=========================================")
    print("Starting in 2 seconds...")
    time.sleep(2)
    print("STARTED.")

    last_key = None
    last_key_time = 0
    last_debug_time = 0
    
    # Debounce for toggle keys
    last_x_press = 0

    while True:
        try:
            # Check for Exit
            if is_key_pressed(VK_F12):
                print("\nStopped by User (F12).")
                break

            # Check for Pause Toggle
            if is_key_pressed(VK_X):
                if time.time() - last_x_press > 0.5: # Debounce
                    PAUSED = not PAUSED
                    status = "PAUSED" if PAUSED else "RESUMED"
                    print(f"Bot {status}")
                    if PAUSED:
                        winsound.Beep(500, 200)
                    else:
                        winsound.Beep(1000, 200)
                    last_x_press = time.time()
            
            if PAUSED:
                time.sleep(0.1)
                continue

            # Capture a larger region to account for window borders
            # Frame is now 32x32 at 0,0. Center is 16,16.
            img = pyautogui.screenshot(region=(0,0, 50, 50))
            
            # Check pixel at (16, 16)
            p = img.getpixel((16, 16))
            
            # Find matching key
            found_key = None
            for color, key in KEYS.items():
                if match_color(p, color):
                    found_key = key
                    break
            
            if found_key:
                # Throttle slightly to avoid spamming too hard, but enough to be responsive
                # User requested "twice as fast" -> 0.05s (20 Hz)
                if found_key != last_key or (time.time() - last_key_time > 0.05):
                    pyautogui.press(found_key)
                    print(f"Action: {found_key} (Color: {p})") 
                    last_key = found_key
                    last_key_time = time.time()
            else:
                # If no color matched (black), reset last key to allow re-casting same spell if needed later
                if last_key is not None and (time.time() - last_key_time > 0.5):
                    last_key = None
                
                # Debug: Show what we see every 3 seconds if nothing matches
                if time.time() - last_debug_time > 3.0:
                    print(f"Seeing Color: {p} (No Match)")
                    last_debug_time = time.time()
                
            time.sleep(0.01) # 100 checks per second
            
        except KeyboardInterrupt:
            print("\nStopped.")
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()
