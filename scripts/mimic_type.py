#!/usr/bin/env python3
import os
import time
import random
from pynput.keyboard import Controller, Key

# A single controller instance keeps all synthetic key events on the same device.
keyboard = Controller()

def delete_autoclose():
    """Universal method to delete auto-inserted closing brackets"""
    keyboard.press(Key.delete)
    keyboard.release(Key.delete)
    time.sleep(random.uniform(0.1, 0.15))

def simulate_typo(char, i, error_chance):
    """Simulates human typing errors with contextual awareness"""
    if random.random() < error_chance and char.isalnum():
        # Generate context-aware wrong character
        if char.isalpha():
            wrong_char = random.choice(
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ" if char.isupper() 
                else "abcdefghijklmnopqrstuvwxyz"
            )
        else:  # Digits
            wrong_char = random.choice("0123456789")

        # Type and correct mistake
        keyboard.press(wrong_char)
        keyboard.release(wrong_char)
        time.sleep(random.uniform(0.2, 0.4))  # Realistic hesitation
        keyboard.press(Key.backspace)
        keyboard.release(Key.backspace)
        time.sleep(random.uniform(0.1, 0.2))  # Correction pause

        # 25% chance to over-correct
        if random.random() < 0.25:
            possible_N = min(random.randint(1, 2), i)
            if possible_N > 0:
                for _ in range(possible_N):
                    keyboard.press(Key.backspace)
                    keyboard.release(Key.backspace)
                    time.sleep(random.uniform(0.08, 0.15))
                # Rewind the cursor position so the caller retries from the
                # earlier character after the deliberate over-correction.
                return (i - possible_N, True)
        return (i, False)
    return (i, False)

def type_simulation(text):
    # Delay bands are tuned to feel like fast but imperfect manual typing.
    base_speed = (0.07, 0.18)        # 70-180ms per character
    punctuation_delay = (0.2, 0.4)   # After , ; : etc
    structural_delay = (0.3, 0.6)    # After { ( [
    linebreak_delay = (0.4, 0.8)     # After Enter
    error_chance = 0.05              # 5% error rate
    
    i = 0
    while i < len(text):
        char = text[i]

        # Newlines need extra recovery time because editors often auto-indent or
        # move the caret unexpectedly after Enter.
        if char == '\n':
            keyboard.press(Key.enter)
            keyboard.release(Key.enter)
            time.sleep(random.uniform(*linebreak_delay))
            
            # Reset to true line start
            with keyboard.pressed(Key.shift):
                keyboard.press(Key.home)
                keyboard.release(Key.home)
            time.sleep(random.uniform(0.1, 0.2))
            i += 1
            continue

        # Tabs are sent as real Tab key events so the target editor can keep its
        # normal indentation behavior.
        if char == '\t':
            keyboard.press(Key.tab)
            keyboard.release(Key.tab)
            time.sleep(random.uniform(0.2, 0.3))  # Allow auto-indent
            i += 1
            continue

        # Simulate human errors
        i, should_continue = simulate_typo(char, i, error_chance)
        if should_continue:
            continue

        # Type correct character
        keyboard.press(char)
        keyboard.release(char)
        
        # Punctuation and structural characters usually introduce a visible
        # pause in real typing, so they get their own timing profile.
        if char in {',', ';', ':'}:
            time.sleep(random.uniform(*punctuation_delay))
        elif char in {'{', '(', '['}:
            time.sleep(random.uniform(*structural_delay))
        else:
            time.sleep(random.uniform(*base_speed))

        # Some editors insert the closing pair automatically, so remove the
        # synthetic duplicate to keep the final text aligned with the source.
        if char in ('(', '{', '['):
            time.sleep(random.uniform(0.25, 0.35))  # Editor response window
            delete_autoclose()
            # Handle following space if needed
            if i+1 < len(text) and text[i+1] == ' ':
                time.sleep(random.uniform(0.15, 0.25))
                keyboard.press(' ')
                keyboard.release(' ')
                i += 1  # Skip input space

        i += 1

def main():
    file_path = os.path.expanduser("~/.macunix/tmp/txt/clip.txt")
    if not os.path.exists(file_path):
        print(f"ERROR: File not found: {file_path}")
        return
    
    # The helper intentionally reads from a file so the producer side can drop
    # in clipboard contents before the typing pass begins.
    with open(file_path, "r") as file:
        text = file.read()
    
    print("Professional typing simulation starting...")
    type_simulation(text)
    print("Typing simulation completed.")

if __name__ == "__main__":
    # time.sleep(2)
    main()
