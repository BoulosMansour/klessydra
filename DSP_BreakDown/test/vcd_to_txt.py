#!/usr/bin/env python3
"""
Improved VCD to TXT converter with better parsing
"""

# def parse_vcd_to_txt(vcd_file, txt_file, target_signals=None):
#     """
#     Convert VCD file to text format with improved parsing
    
#     Args:
#         vcd_file: Input VCD file path
#         txt_file: Output text file path
#         target_signals: List of signal names to extract (None for all)
#     """
    
#     signal_map = {}  # Maps symbol to (signal_name, size)
#     signal_values = {}  # Current values of signals
    
#     try:
#         with open(vcd_file, 'r', encoding='utf-8', errors='ignore') as f_in:
#             lines = f_in.readlines()
#     except:
#         with open(vcd_file, 'r', encoding='latin-1') as f_in:
#             lines = f_in.readlines()
    
#     with open(txt_file, 'w') as f_out:
#         f_out.write("# Time\tSignal\tValue\n")
        
#         current_time = 0
#         in_header = True
#         changes_found = 0
        
#         print(f"Processing {len(lines)} lines...")
        
#         for i, line in enumerate(lines):
#             line = line.strip()
            
#             if not line:
#                 continue
            
#             # Skip comments
#             if line.startswith('$comment'):
#                 continue
                
#             # Parse variable declarations
#             if line.startswith('$var'):
#                 parts = line.split()
#                 if len(parts) >= 5:
#                     var_type = parts[1]
#                     size = int(parts[2])
#                     symbol = parts[3]
#                     name = ' '.join(parts[4:]).rstrip(' $end')  # Handle names with spaces
                    
#                     # Clean up signal name
#                     name = name.replace('[', '_').replace(']', '_').replace('$end', '').strip()
                    
#                     # Only include target signals if specified
#                     if target_signals is None or any(target in name for target in target_signals):
#                         signal_map[symbol] = (name, size)
#                         signal_values[symbol] = 'x'
#                         print(f"Found signal: {name} -> {symbol} (size: {size})")
                
#             # End of header
#             elif line.startswith('$enddefinitions') or line.startswith('$end'):
#                 if '$enddefinitions' in line:
#                     in_header = False
#                     print("Header parsing complete. Starting value changes...")
                
#             # Skip other header commands
#             elif line.startswith('$'):
#                 continue
                
#             # Parse time changes
#             elif line.startswith('#'):
#                 try:
#                     current_time = int(line[1:])
#                     if changes_found % 100 == 0 and changes_found > 0:
#                         print(f"Processing time: {current_time}, changes so far: {changes_found}")
#                 except ValueError:
#                     print(f"Warning: Invalid time format: {line}")
#                     continue
                
#             # Parse value changes (only after header)
#             elif not in_header and line:
#                 value_written = False
                
#                 # Handle different value change formats
#                 if len(line) >= 2:
#                     # Format 1: Single bit (0a, 1a, xa, za)
#                     if line[0] in '01xzXZ' and len(line) >= 2:
#                         value = line[0]
#                         symbol = line[1:]
                        
#                         if symbol in signal_map:
#                             signal_name, size = signal_map[symbol]
#                             f_out.write(f"{current_time}\t{signal_name}\t{value}\n")
#                             changes_found += 1
#                             value_written = True
                    
#                     # Format 2: Multi-bit binary (b101010 symbol)
#                     elif line[0] in 'bBrR':
#                         parts = line.split()
#                         if len(parts) >= 2:
#                             value = line.split()[0]  # Keep the 'b' prefix for clarity
#                             symbol = parts[1]
                            
#                             if symbol in signal_map:
#                                 signal_name, size = signal_map[symbol]
#                                 # Convert binary to more readable format
#                                 clean_value = value[1:] if value.startswith('b') else value
#                                 f_out.write(f"{current_time}\t{signal_name}\t{clean_value}\n")
#                                 changes_found += 1
#                                 value_written = True
                    
#                     # Format 3: Space-separated value and symbol
#                     elif ' ' in line:
#                         parts = line.split()
#                         if len(parts) >= 2:
#                             value = parts[0]
#                             symbol = parts[1]
                            
#                             if symbol in signal_map:
#                                 signal_name, size = signal_map[symbol]
#                                 f_out.write(f"{current_time}\t{signal_name}\t{value}\n")
#                                 changes_found += 1
#                                 value_written = True
                
#                 # Debug: Print unrecognized lines
#                 if not value_written and not in_header and line and not line.startswith('$'):
#                     if changes_found < 10:  # Only print first few for debugging
#                         print(f"Unrecognized line {i}: '{line}'")
        
#         print(f"Conversion complete! Found {changes_found} signal changes.")
#         print(f"Tracked {len(signal_map)} signals.")
        
#         if changes_found == 0:
#             print("WARNING: No signal changes found. This might indicate:")
#             print("1. The VCD file format is different than expected")
#             print("2. All signals are in the header but no actual changes recorded")
#             print("3. The file might be corrupted or incomplete")
            
#             # Let's print some debug info
#             print(f"\nSignals found in header: {len(signal_map)}")
#             for symbol, (name, size) in signal_map.items():
#                 print(f"  {symbol} -> {name} (size: {size})")

def parse_vcd_to_txt_grouped(vcd_file, txt_file, target_signals=None):
    """
    Convert VCD file to grouped text format where multi-bit signals (e.g., pc_IE_0_) are merged into vectors.
    """
    import re
    from collections import defaultdict

    signal_map = {}  # Maps symbol -> (full_name, size)
    current_values = {}  # symbol -> value
    bitfields = defaultdict(dict)  # signal_name -> bit_index -> symbol
    timewise_changes = defaultdict(lambda: defaultdict(dict))  # time -> signal_name -> bit_index -> value

    try:
        with open(vcd_file, 'r', encoding='utf-8', errors='ignore') as f_in:
            lines = f_in.readlines()
    except:
        with open(vcd_file, 'r', encoding='latin-1') as f_in:
            lines = f_in.readlines()

    current_time = 0
    in_header = True
    changes_found = 0

    print(f"Processing {len(lines)} lines...")

    for i, line in enumerate(lines):
        line = line.strip()

        if not line or line.startswith('$comment'):
            continue

        # Header parsing
        if in_header:
            if line.startswith('$var'):
                parts = line.split()
                if len(parts) >= 5:
                    size = int(parts[2])
                    symbol = parts[3]
                    name = ' '.join(parts[4:-1])
                    name = name.replace('[', '_').replace(']', '_').replace('$end', '').strip()

                    if target_signals is None or any(target in name for target in target_signals):
                        signal_map[symbol] = (name, size)
                        current_values[symbol] = 'x'

                        match = re.match(r'(.+)_([0-9]+)_$', name)
                        if match:
                            base, idx = match.group(1), int(match.group(2))
                            bitfields[base][idx] = symbol
                        else:
                            bitfields[name][-1] = symbol  # single-bit scalar
            elif '$enddefinitions' in line:
                in_header = False
                print("Header parsing complete. Starting value changes...")
            continue

        # Time change
        if line.startswith('#'):
            try:
                current_time = int(line[1:])
            except ValueError:
                print(f"Warning: Invalid time format: {line}")
            continue

        # Value changes
        value_written = False
        if len(line) >= 2:
            if line[0] in '01xzXZ':
                value = line[0]
                symbol = line[1:]
            elif line[0] in 'bBrR':
                parts = line.split()
                if len(parts) >= 2:
                    value = parts[0][1:]  # remove 'b'
                    symbol = parts[1]
                else:
                    continue
            elif ' ' in line:
                parts = line.split()
                value, symbol = parts[0], parts[1]
            else:
                continue

            if symbol in signal_map:
                current_values[symbol] = value
                signal_name, _ = signal_map[symbol]

                match = re.match(r'(.+)_([0-9]+)_$', signal_name)
                if match:
                    base, idx = match.group(1), int(match.group(2))
                    timewise_changes[current_time][base][idx] = value
                else:
                    timewise_changes[current_time][signal_name][-1] = value
                changes_found += 1
                value_written = True

        if not value_written and changes_found < 10:
            print(f"Unrecognized line {i}: '{line}'")

    # Write output
    with open(txt_file, 'w') as f_out:
        f_out.write("# Time\tSignal\tValue\n")
        for time in sorted(timewise_changes.keys()):
            for name in sorted(timewise_changes[time].keys()):
                bits = timewise_changes[time][name]
                if -1 in bits:
                    value = bits[-1]
                else:
                    width = max(bits.keys()) + 1
                    val_arr = ['x'] * width
                    for i, v in bits.items():
                        val_arr[i] = v
                    value = ''.join(reversed(val_arr))  # MSB first
                f_out.write(f"{time}\t{name}\t{value}\n")

    print(f"Conversion complete! Found {changes_found} signal changes.")
    print(f"Grouped signals written to: {txt_file}")

def preview_vcd_file(vcd_file, num_lines=50):
    """
    Preview the first few lines of a VCD file for debugging
    """
    print(f"=== Preview of {vcd_file} (first {num_lines} lines) ===")
    try:
        with open(vcd_file, 'r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f):
                if i >= num_lines:
                    break
                print(f"{i+1:3d}: {repr(line.rstrip())}")
    except Exception as e:
        print(f"Error reading file: {e}")

def extract_signal_to_stimulus(txt_file, signal_name, output_file, time_step=None):
    """
    Extract a specific signal from the parsed VCD data and create a stimulus file
    """
    values = []
    times = []
    
    with open(txt_file, 'r') as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
                
            parts = line.strip().split('\t')
            if len(parts) >= 3:
                time_val = int(parts[0])
                sig_name = parts[1]
                value = parts[2]
                
                if signal_name.lower() in sig_name.lower():
                    times.append(time_val)
                    values.append(value)
    
    print(f"Found {len(values)} changes for signal containing '{signal_name}'")
    
    with open(output_file, 'w') as f:
        f.write(f"// Stimulus for signal: {signal_name}\n")
        f.write(f"// Found {len(values)} value changes\n")
        for i, (time_val, value) in enumerate(zip(times, values)):
            f.write(f"// Time: {time_val}\n")
            f.write(f"{value}\n")

# Example usage and debugging
if __name__ == "__main__":
    import sys
    
    # Get VCD file name
    if len(sys.argv) > 1:
        vcd_file = sys.argv[1]
    else:
        vcd_file = input("Enter VCD file path: ").strip()
    
    if not vcd_file:
        vcd_file = "input.vcd"  # Default name
    
    txt_file = vcd_file.replace('.vcd', '_converted.txt')
    
    print(f"Converting: {vcd_file} -> {txt_file}")
    
    # First, preview the file to see its structure
    preview_vcd_file(vcd_file, 20)
    
    # Convert VCD to text
    parse_vcd_to_txt_grouped(vcd_file, txt_file)
    
    # Check if conversion worked
    try:
        with open(txt_file, 'r') as f:
            lines = f.readlines()
            if len(lines) > 1:
                print(f"\nSuccess! Generated {len(lines)-1} data lines in {txt_file}")
                print("First few data lines:")
                for i in range(min(10, len(lines))):
                    print(f"  {lines[i].rstrip()}")
            else:
                print(f"\nNo data generated. Check the preview above for VCD format issues.")
    except Exception as e:
        print(f"Error reading output file: {e}")