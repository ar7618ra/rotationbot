import pyautogui
import time
import math
import random
import winsound
import ctypes

# =====================================================================================
# FROSTMOURNE FISHING BOT (WotLK 3.3.5a) - V2
# =====================================================================================
# INSTRUCTIONS:
# 1. Assign '1' to the "Fishing" skill in WoW Keybindings.
# 2. Equip your Fishing Pole.
# 3. Enable "Interact on Left Click" in WoW Interface settings.
# 4. Zoom your camera in slightly.
# 5. Run this script.
# 6. Press 'F8' to Pause/Resume the bot. Press 'F12' to Exit.
# =====================================================================================

# CONFIGURATION
FISHING_KEY = '1'       # Key bound to Fishing
SCAN_STEP = 30          # Grid spacing
SPLASH_THRESHOLD = 25   # Sensitivity for splash detection.

# ADDON COLOR CODES
TARGET_COLOR_YELLOW = (255, 255, 0)
TOLERANCE = 60          # Higher tolerance for color variance / scaling
STATUS_SAMPLE_SIZE = 6  # Square sample (pixels)

# KEY CODES
VK_F8 = 0x77
VK_F12 = 0x7B
VK_F5 = 0x74 # Set Top-Left
VK_F6 = 0x75 # Set Bottom-Right
VK_F2 = 0x71 # Set Status Pixel

PAUSED = False
SCAN_AREA = None # (x, y, width, height)
STATUS_PIXEL = (16, 16) # Defaults to top-left corner

def is_key_pressed(vk_code):
    return ctypes.windll.user32.GetAsyncKeyState(vk_code) & 0x8000

def setup_status_pixel():
    """Calibrate where the addon indicator is on the screen."""
    global STATUS_PIXEL

    print("\n=== STATUS PIXEL SETUP ===")
    print("Move your mouse over the addon's indicator square (should turn yellow) and press F2.")
    print("If you keep WoW fullscreen anchored to the top-left, you can just press F7 immediately.")

    while True:
        if is_key_pressed(VK_F2):
            STATUS_PIXEL = pyautogui.position()
            print(f"Status pixel recorded at: {STATUS_PIXEL}")
            winsound.Beep(1200, 150)
            time.sleep(0.5)
            return True
        if is_key_pressed(VK_F12):
            return False
        time.sleep(0.1)

def setup_scan_area():
    """Allows user to define the scan box manually."""
    print("\n=== MANUAL SCAN AREA SETUP ===")
    print("1. Move mouse to TOP-LEFT of the water.")
    print("2. Press F5.")
    
    tl_x, tl_y = 0, 0
    br_x, br_y = 0, 0
    
    while True:
        if is_key_pressed(VK_F5):
            tl_x, tl_y = pyautogui.position()
            print(f"Top-Left set to: {tl_x}, {tl_y}")
            winsound.Beep(1000, 200)
            time.sleep(1)
            break
        if is_key_pressed(VK_F12): return False
        time.sleep(0.1)
        
    print("3. Move mouse to BOTTOM-RIGHT of the water.")
    print("4. Press F6.")
    
    while True:
        if is_key_pressed(VK_F6):
            br_x, br_y = pyautogui.position()
            print(f"Bottom-Right set to: {br_x}, {br_y}")
            winsound.Beep(1000, 200)
            time.sleep(1)
            break
        if is_key_pressed(VK_F12): return False
        time.sleep(0.1)
        
    width = abs(br_x - tl_x)
    height = abs(br_y - tl_y)
    x = min(tl_x, br_x)
    y = min(tl_y, br_y)
    
    global SCAN_AREA
    SCAN_AREA = (x, y, width, height)
    print(f"Area Set: {SCAN_AREA}")
    return True

def match_color(pixel, target_rgb):
    r, g, b = pixel
    tr, tg, tb = target_rgb
    return (abs(r - tr) < TOLERANCE and 
            abs(g - tg) < TOLERANCE and 
            abs(b - tb) < TOLERANCE)

def get_addon_status():
    """Reads the pixel at (16, 16) to see if Addon found the bobber."""
    try:
        sx = max(STATUS_PIXEL[0] - STATUS_SAMPLE_SIZE // 2, 0)
        sy = max(STATUS_PIXEL[1] - STATUS_SAMPLE_SIZE // 2, 0)
        img = pyautogui.screenshot(region=(sx, sy, STATUS_SAMPLE_SIZE, STATUS_SAMPLE_SIZE))

        total_r = total_g = total_b = 0
        count = 0
        for x in range(img.width):
            for y in range(img.height):
                r, g, b = img.getpixel((x, y))
                total_r += r
                total_g += g
                total_b += b
                count += 1
        if count == 0:
            return (0,0,0)
        return (total_r // count, total_g // count, total_b // count)
    except Exception:
        return (0,0,0)

def grid_scan():
    """Scans the screen in a SPIRAL BOX pattern starting from center."""
    if SCAN_AREA:
        start_x, start_y, max_width, max_height = SCAN_AREA
        screen_w, screen_h = max_width, max_height # relative sizing
        center_x = start_x + max_width // 2
        center_y = start_y + max_height // 2
    else:
        screen_w, screen_h = pyautogui.size()
        center_x, center_y = screen_w // 2, screen_h // 2
        max_width = int(screen_w * 0.90)
        max_height = int(screen_h * 0.80)
    
    print("Scanning (Spiral Box)...")
    start_time = time.time()
    
    x, y = center_x, center_y
    dx, dy = SCAN_STEP, 0 # Start moving right
    segment_length = 1
    segment_passed = 0
    
    # Initial check at center
    if match_color(get_addon_status(), TARGET_COLOR_YELLOW):
        return (x, y)

    while True:
        # Check pause/exit
        if is_key_pressed(VK_F8) or is_key_pressed(VK_F12): return False
        if time.time() - start_time > 10: return False # Timeout

        # Move
        x += dx
        y += dy
        segment_passed += 1
        
        # Check bounds (if inside defined area)
        if (x >= center_x - max_width//2 and x <= center_x + max_width//2 and
            y >= center_y - max_height//2 and y <= center_y + max_height//2):
            
            pyautogui.moveTo(x, y, duration=0)
            time.sleep(0.002) # Slight pause for tooltip update
            
            if match_color(get_addon_status(), TARGET_COLOR_YELLOW):
                print(f"Bobber found at {x}, {y}!")
                return (x, y)
        else:
            pass # Spin until next turn brings us back or timeout

        # Turn corner?
        if segment_passed >= segment_length:
            segment_passed = 0
            # Rotate direction: (1,0) -> (0,1) -> (-1,0) -> (0,-1)
            dx, dy = -dy, dx
            
            # Increase length every 2 segments (Right, Down | Left, Up | Right, Down...)
            if dy == 0:
                segment_length += 1
                
    return False

def wait_for_splash(mouse_pos):
    """Monitors the area under the mouse for pixel changes (Splash)."""
    x, y = mouse_pos
    box_size = 40
    box_x = x - box_size // 2
    box_y = y - box_size // 2
    
    print("Waiting for splash...")
    try:
        last_img = pyautogui.screenshot(region=(box_x, box_y, box_size, box_size))
    except:
        return False

    start_wait = time.time()
    
    while time.time() - start_wait < 19:
        if is_key_pressed(VK_F8): return False # Exit if paused
        
        try:
            curr_img = pyautogui.screenshot(region=(box_x, box_y, box_size, box_size))
        except:
            continue
        
        diff_score = 0
        width, height = curr_img.size
        for px in range(0, width, 3):
            for py in range(0, height, 3):
                r1, g1, b1 = last_img.getpixel((px, py))
                r2, g2, b2 = curr_img.getpixel((px, py))
                if abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2) > 30:
                    diff_score += 1
        
        if diff_score > SPLASH_THRESHOLD * 5:
            print(f"Splash detected! Score: {diff_score}")
            return True
            
        last_img = curr_img
        time.sleep(0.05)
        
    return False

def main():
    global PAUSED
    print("----------------------------------------")
    print("   Frostmourne Fishing Bot V2           ")
    print("   [F8]  Toggle Pause/Resume            ")
    print("   [F12] Stop Script                    ")
    print("----------------------------------------")
    
    # STATUS PIXEL SETUP
    if not setup_status_pixel():
        print("Status calibration cancelled.")
        return

    # SETUP AREA
    if not setup_scan_area():
        print("Setup cancelled.")
        return

    print("Starting in 3 seconds...")
    time.sleep(3)
    
    catches = 0
    last_f8 = 0
    
    try:
        while True:
            # Check Exit
            if is_key_pressed(VK_F12):
                print("\nStopped by User (F12).")
                break
                
            # Check Pause
            if is_key_pressed(VK_F8):
                if time.time() - last_f8 > 0.5:
                    PAUSED = not PAUSED
                    state = "PAUSED" if PAUSED else "RESUMED"
                    print(f"\nBot {state}")
                    winsound.Beep(500 if PAUSED else 1000, 200)
                    last_f8 = time.time()
            
            if PAUSED:
                time.sleep(0.1)
                continue

            # 1. Cast
            print("\nCasting...")
            pyautogui.press(FISHING_KEY)
            time.sleep(2.0) 
            
            # 2. Scan
            bobber_pos = grid_scan()
            
            if bobber_pos:
                # 3. Wait Splash
                if wait_for_splash(bobber_pos):
                    # 4. Loot
                    pyautogui.keyDown('shift')
                    pyautogui.click(button='right')
                    pyautogui.keyUp('shift')
                    
                    print("Looting...")
                    catches += 1
                    winsound.Beep(1000, 100)
                    time.sleep(2.5)
                else:
                    print("Timed out or interrupted.")
            else:
                print("Bobber not found.")
            
            # Sleep with random element
            sleep_time = random.uniform(0.5, 1.0)
            start_sleep = time.time()
            while time.time() - start_sleep < sleep_time:
                if is_key_pressed(VK_F8) or is_key_pressed(VK_F12): break
                time.sleep(0.1)
                
    except KeyboardInterrupt:
        print(f"\nBot Stopped. Total Catches: {catches}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
