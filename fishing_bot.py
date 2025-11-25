import pyautogui
import time
import math
import random
import winsound

# =====================================================================================
# FROSTMOURNE FISHING BOT (WotLK 3.3.5a)
# =====================================================================================
# INSTRUCTIONS:
# 1. Assign '1' to the "Fishing" skill in WoW Keybindings.
# 2. Equip your Fishing Pole.
# 3. Enable "Interact on Left Click" in WoW Interface settings.
# 4. Zoom your camera in slightly or position it so the bobber lands near the center.
# 5. Run this script using: python fishing_bot.py
# =====================================================================================

# CONFIGURATION
FISHING_KEY = '1'       # Key bound to Fishing
SCAN_RADIUS = 350       # How far from center to scan (pixels)
SPLASH_THRESHOLD = 25   # Sensitivity for splash detection. Increase if bobbing triggers it.

# ADDON COLOR CODES
# The Lua addon sets the top-left frame to BLUE (0, 0, 255) when the mouse is over "Fishing Bobber"
TARGET_COLOR_BLUE = (0, 0, 255)
TOLERANCE = 10

def match_color(pixel, target_rgb):
    r, g, b = pixel
    tr, tg, tb = target_rgb
    return (abs(r - tr) < TOLERANCE and 
            abs(g - tg) < TOLERANCE and 
            abs(b - tb) < TOLERANCE)

def get_addon_status():
    """Reads the pixel at (16, 16) to see if Addon found the bobber."""
    # We grab a small chunk at 0,0 to ensure we get the frame
    try:
        img = pyautogui.screenshot(region=(0, 0, 32, 32))
        return img.getpixel((16, 16))
    except Exception:
        return (0,0,0)

def spiral_scan():
    """Moves mouse in a spiral from center to find the bobber."""
    screen_w, screen_h = pyautogui.size()
    center_x, center_y = screen_w // 2, screen_h // 2
    
    print("Scanning for bobber...")
    
    angle = 0
    radius = 20
    
    # Start at center
    pyautogui.moveTo(center_x, center_y)
    start_time = time.time()
    
    while radius < SCAN_RADIUS:
        if time.time() - start_time > 6: # Timeout
            return False

        # Calculate position
        x = center_x + int(radius * math.cos(angle))
        y = center_y + int(radius * math.sin(angle))
        
        # Move mouse
        pyautogui.moveTo(x, y, duration=0) 
        time.sleep(0.02) # Wait for Tooltip/Addon update
        
        # Check Addon Signal
        color = get_addon_status()
        if match_color(color, TARGET_COLOR_BLUE):
            print(f"Bobber found at {x}, {y}!")
            return (x, y)
            
        angle += 0.4 
        radius += 1.2
        
    return False

def wait_for_splash(mouse_pos):
    """Monitors the area under the mouse for pixel changes (Splash)."""
    x, y = mouse_pos
    box_size = 40
    box_x = x - box_size // 2
    box_y = y - box_size // 2
    
    print("Waiting for splash...")
    last_img = pyautogui.screenshot(region=(box_x, box_y, box_size, box_size))
    start_wait = time.time()
    
    while time.time() - start_wait < 19: 
        curr_img = pyautogui.screenshot(region=(box_x, box_y, box_size, box_size))
        
        # Check for visual difference
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
    print("Starting Fishing Bot in 3 seconds... Switch to WoW!")
    time.sleep(3)
    catches = 0
    
    try:
        while True:
            print("\nCasting...")
            pyautogui.press(FISHING_KEY)
            time.sleep(2.0) # Wait for cast
            
            bobber_pos = spiral_scan()
            
            if bobber_pos:
                if wait_for_splash(bobber_pos):
                    # Shift+Right Click to Auto-Loot
                    pyautogui.keyDown('shift')
                    pyautogui.click(button='right')
                    pyautogui.keyUp('shift')
                    
                    print("Looting...")
                    catches += 1
                    winsound.Beep(1000, 100)
                    time.sleep(2.5) 
                else:
                    print("Timed out.")
            else:
                print("Bobber not found.")
            
            time.sleep(random.uniform(0.5, 1.0))
            
    except KeyboardInterrupt:
        print(f"\nBot Stopped. Total Catches: {catches}")

if __name__ == "__main__":
    main()
