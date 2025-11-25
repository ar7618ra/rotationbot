import time
import random
import ctypes
import winsound
import os

import cv2
import mss
import numpy as np
import pyautogui

"""
OpenCV-Based Fishing Bot (Template Matching)
---------------------------------------------
Requirements:
    pip install opencv-python mss numpy pyautogui

Setup:
    1. Take a screenshot of just the bobber (cropped tight, ~40x40 to 60x60 pixels).
    2. Save it as 'bobber.png' in the RotationBot folder.
    3. Run this script.

Usage:
    1. Calibrate the scan region (F5 = top-left, F6 = bottom-right).
    2. Zoom your camera so the bobber lands inside that region.
    3. The bot casts, finds the bobber via template matching, waits for splash, then loots.
"""

# ================= CONFIGURATION =================
FISHING_KEY = '1'            # Key bound to Fishing skill
ROI_DEFAULT = None           # If you want a default region, set to (left, top, right, bottom)
DEBUG_WINDOW = True          # Set True to show detection window

# Multiple templates for better matching
TEMPLATE_DIR = os.path.dirname(__file__)
TEMPLATE_FILES = ["bobber_bright1.png", "bobber_bright2.png", "bobber_bright3.png"]
MATCH_THRESHOLD = 0.6        # 0.0 to 1.0 - lower = more matches but more false positives

BITE_THRESHOLD = 80          # Extremely sensitive (was 1000)
BITE_TIMEOUT = 20            # Seconds to wait for a bite
SCAN_DELAY = 0.05            # Delay between detection frames

# Keybinds
aVK_F8 = 0x77  # Pause/Resume
aVK_F12 = 0x7B # Exit
aVK_F5 = 0x74  # ROI top-left
aVK_F6 = 0x75  # ROI bottom-right

PAUSED = False
ROI = ROI_DEFAULT  # (left, top, right, bottom)
TEMPLATES = []     # Will be loaded at startup

# =================================================

def is_key_pressed(vk_code):
    return ctypes.windll.user32.GetAsyncKeyState(vk_code) & 0x8000

def load_templates():
    global TEMPLATES
    TEMPLATES = []
    
    for filename in TEMPLATE_FILES:
        path = os.path.join(TEMPLATE_DIR, filename)
        if os.path.exists(path):
            img = cv2.imread(path)
            if img is not None:
                TEMPLATES.append(img)
                print(f"Loaded template: {filename} ({img.shape[1]}x{img.shape[0]} pixels)")
            else:
                print(f"Warning: Could not load {filename}")
        else:
            print(f"Warning: Template not found: {filename}")
    
    if not TEMPLATES:
        print("ERROR: No templates loaded! Add bobber_bright1.png, etc. to RotationBot folder.")
        return False
    
    print(f"Total templates loaded: {len(TEMPLATES)}")
    return True

def setup_roi():
    global ROI
    print("\n=== ROI SETUP ===")
    print("1) Move cursor to TOP-LEFT corner of water region and press F5.")
    print("2) Move cursor to BOTTOM-RIGHT corner and press F6.")
    tl = br = None

    while tl is None:
        if is_key_pressed(aVK_F5):
            tl = pyautogui.position()
            print(f"Top-Left set to: {tl}")
            winsound.Beep(900, 150)
            time.sleep(0.4)
        elif is_key_pressed(aVK_F12):
            return False
        time.sleep(0.1)

    while br is None:
        if is_key_pressed(aVK_F6):
            br = pyautogui.position()
            print(f"Bottom-Right set to: {br}")
            winsound.Beep(1100, 150)
            time.sleep(0.4)
        elif is_key_pressed(aVK_F12):
            return False
        time.sleep(0.1)

    left = min(tl.x, br.x)
    top = min(tl.y, br.y)
    right = max(tl.x, br.x)
    bottom = max(tl.y, br.y)

    ROI = (left, top, right, bottom)
    print(f"ROI locked: {ROI}")
    return True

def grab_frame(sct, region):
    left, top, right, bottom = region
    monitor = {
        "left": left,
        "top": top,
        "width": right - left,
        "height": bottom - top
    }
    frame = np.array(sct.grab(monitor))
    frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
    return frame

def find_bobber(frame):
    """Find bobber using template matching across all templates."""
    if not TEMPLATES:
        return None
    
    best_match_val = 0
    best_match_loc = None
    best_template = None
    
    for template in TEMPLATES:
        result = cv2.matchTemplate(frame, template, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, max_loc = cv2.minMaxLoc(result)
        
        if max_val > best_match_val:
            best_match_val = max_val
            best_match_loc = max_loc
            best_template = template
    
    # Debug window
    if DEBUG_WINDOW:
        debug_frame = frame.copy()
        if best_template is not None and best_match_val >= MATCH_THRESHOLD:
            h, w = best_template.shape[:2]
            top_left = best_match_loc
            bottom_right = (top_left[0] + w, top_left[1] + h)
            cv2.rectangle(debug_frame, top_left, bottom_right, (0, 255, 0), 2)
            cv2.putText(debug_frame, f"{best_match_val:.2f}", (top_left[0], top_left[1] - 5),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
        cv2.imshow("Bobber Detection", debug_frame)
        cv2.waitKey(1)
    
    if best_match_val >= MATCH_THRESHOLD and best_template is not None:
        h, w = best_template.shape[:2]
        cx = best_match_loc[0] + w // 2
        cy = best_match_loc[1] + h // 2
        return cx, cy
    
    return None

def wait_for_bite(sct, screen_pos):
    left = max(screen_pos[0] - 50, 0)
    top = max(screen_pos[1] - 50, 0)
    monitor = {
        "left": left,
        "top": top,
        "width": 100,
        "height": 100
    }

    # Debug: Draw where we are looking
    if DEBUG_WINDOW:
        # Create a dummy image just to show the box (overlay on full screen would be slow, so we just print)
        # Or we can use a small window showing the monitored area
        pass

    prev = np.array(sct.grab(monitor))
    prev_gray = cv2.cvtColor(prev, cv2.COLOR_BGRA2GRAY)
    start = time.time()

    while time.time() - start < BITE_TIMEOUT:
        if is_key_pressed(aVK_F8):
            return False

        curr = np.array(sct.grab(monitor))
        curr_gray = cv2.cvtColor(curr, cv2.COLOR_BGRA2GRAY)
        
        # Show what the bot sees for splash detection
        if DEBUG_WINDOW:
            cv2.imshow("Splash Monitor", curr)
            cv2.waitKey(1)

        diff = cv2.absdiff(curr_gray, prev_gray)
        score = np.sum(diff > 15) # Lowered from 25 for sensitivity

        if score > 100: 
            print(f"Splash score: {score}")

        if score > BITE_THRESHOLD:
            print(f"Splash detected: score={score}")
            if DEBUG_WINDOW:
                cv2.destroyWindow("Splash Monitor")
            return True

        prev_gray = curr_gray
        time.sleep(0.01)

    if DEBUG_WINDOW:
        cv2.destroyWindow("Splash Monitor")
    return False

def main():
    global PAUSED
    print("----------------------------------------")
    print("   Frostmourne Fishing Bot (OpenCV)     ")
    print("   Template Matching Mode               ")
    print("   [F8] Toggle Pause | [F12] Quit       ")
    print("----------------------------------------")

    # Load templates
    if not load_templates():
        return

    if ROI is None:
        if not setup_roi():
            print("ROI setup cancelled.")
            return

    print("\nStarting in 2 seconds...")
    time.sleep(2)
    
    catches = 0
    last_toggle = 0
    last_afk_time = time.time()

    with mss.mss() as sct:
        try:
            while True:
                if is_key_pressed(aVK_F12):
                    print("\nStopped by user (F12)")
                    break

                if is_key_pressed(aVK_F8):
                    if time.time() - last_toggle > 0.4:
                        PAUSED = not PAUSED
                        status = "PAUSED" if PAUSED else "RESUMED"
                        print(f"\nBot {status}")
                        winsound.Beep(700 if PAUSED else 1100, 200)
                        last_toggle = time.time()
                if PAUSED:
                    time.sleep(0.2)
                    continue

                # Anti-AFK: Jump or move slightly every ~7-12 minutes
                if time.time() - last_afk_time > random.uniform(400, 700):
                    print("Anti-AFK: Performing random action...")
                    action = random.choice(['space', 'a', 'd'])
                    pyautogui.press(action)
                    last_afk_time = time.time()
                    time.sleep(1)

                print("\nCasting...")
                pyautogui.press(FISHING_KEY)
                # Randomized wait for bobber to land
                time.sleep(random.uniform(1.8, 2.3))

                bobber_screen = None
                detect_start = time.time()
                while time.time() - detect_start < 6:
                    frame = grab_frame(sct, ROI)
                    rel = find_bobber(frame)
                    if rel:
                        bobber_screen = (ROI[0] + rel[0], ROI[1] + rel[1])
                        print(f"Bobber found at: {bobber_screen}")
                        break
                    time.sleep(SCAN_DELAY)

                if not bobber_screen:
                    print("Bobber not found. Recasting...")
                    time.sleep(random.uniform(0.5, 1.0)) # Randomize re-cast delay
                    continue

                # Move mouse to bobber position immediately with randomized curve/speed
                pyautogui.moveTo(bobber_screen[0], bobber_screen[1], duration=random.uniform(0.2, 0.4))
                print("Waiting for bite...")
                
                if wait_for_bite(sct, bobber_screen):
                    # Click on the bobber to loot - Robust method
                    winsound.Beep(1200, 120)
                    
                    # Randomized reaction time (human-like)
                    time.sleep(random.uniform(0.05, 0.15))

                    # Ensure we are still on target
                    pyautogui.moveTo(bobber_screen[0], bobber_screen[1], duration=0.1)
                    
                    # Explicit click sequence
                    pyautogui.mouseDown(button='right')
                    time.sleep(random.uniform(0.08, 0.15))  # Random hold duration
                    pyautogui.mouseUp(button='right')
                    
                    catches += 1
                    print(f"Looted! Total catches: {catches}")
                    time.sleep(random.uniform(2.5, 4.0)) # Longer break between catches
                else:
                    print("No splash detected (timeout).")
                    time.sleep(random.uniform(0.5, 1.0))

        except KeyboardInterrupt:
            print(f"\nStopped manually. Total catches: {catches}")
        except Exception as exc:
            print(f"Error: {exc}")
        finally:
            cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
