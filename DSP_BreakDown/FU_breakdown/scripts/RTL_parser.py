import re
import argparse

argparser = argparse.ArgumentParser()
argparser.add_argument("input", type=str)
input_args = argparser.parse_args()

# Defines
input_file = input_args.input
output_file = input_file.replace(".vhd", "_syn.vhd")

def extr_pare_cont(line):
    return re.findall(r'\((.*?)\)', line)

# This function was changed to deal with bug in Shifter generation
# If there is any problem in the code maybe it is here
def extr_pare_cont_a2d(line):
    result = []
    par_count = 0
    start = None
    for i, c in enumerate(line):
        if c == '(':
            if par_count == 0:
                start = i + 1
            par_count += 1
        elif c == ')':
            par_count -= 1
            if par_count == 0 and start is not None:
                result.append(line[start:i])
                start = None
    return result

signals_2d = {}
signals_3d = {}

def parser_idx(param):
    idx = param.split()[0].split('-')[0]
    
    if not '-' in param and 'downto' in param:
        try:
            idx = str(int(idx) + 1)
        except:
            idx = idx + ' + 1'
    else:
        try:
            idx = str(int(idx))
        except:
            idx = idx
    
    return idx

def parser_line(line):
    parsed_l = line

    if not line.strip()[0:2] == '--':
        for signal in signals_2d:
            i_idx = 0
            for _ in range(parsed_l.count(signal + '(')): 
                i_idx = parsed_l.index(signal + '(', i_idx+1) 
                f_idx = i_idx + len(signal)

                if parsed_l[i_idx-1] in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_':
                    continue

                par_count = 0
                counter = 0
                for car in parsed_l[f_idx:]:
                    if car == '(':
                        par_count += 1
                    elif car == ')':
                        par_count -= 1

                    if ((car == ' ' or car == '\'') and par_count == 0) or par_count < 0:
                        break
                    counter += 1
                i_idx = f_idx
                f_idx += counter

                if f_idx >= len(parsed_l):
                    f_idx = len(parsed_l)-2

                opr = parsed_l[i_idx:f_idx]
                opr_n = '('

                if opr.count('(') == 1:
                    opr = extr_pare_cont(opr)

                    opr_n += f'(({opr[0]}+1)*({signals_2d[signal][1]}))-1 downto ({signals_2d[signal][1]})*({opr[0]})'
                else:
                    opr = extr_pare_cont_a2d(opr)

                    if not 'downto' in opr[1]:
                        opr_n += f'({opr[0]})*({signals_2d[signal][1]}) + {opr[1]}'
                    else:
                        opr_1 = opr[1].split('downto', 1) # Maybe with more downto it will broke
                        opr_n += f'{opr_1[0]} + ({opr[0]})*({signals_2d[signal][1]}) downto {opr_1[1]} + ({opr[0]})*({signals_2d[signal][1]})'

                opr_n += ')'

                parsed_l = parsed_l[:i_idx] + opr_n + parsed_l[f_idx:]
        for signal in signals_3d:
            i_idx = 0
            for _ in range(parsed_l.count(signal + '(')): 
                i_idx = parsed_l.index(signal + '(', i_idx+1) 
                f_idx = i_idx + len(signal)

                if parsed_l[i_idx-1] in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_':
                    continue

                par_count = 0
                counter = 0
                for car in parsed_l[f_idx:]:
                    if car == '(':
                        par_count += 1
                    elif car == ')':
                        par_count -= 1

                    if ((car == ' ' or car == '\'') and par_count == 0) or par_count < 0:
                        break
                    counter += 1
                i_idx = f_idx
                f_idx += counter

                if f_idx >= len(parsed_l):
                    f_idx = len(parsed_l)-2

                opr = parsed_l[i_idx:f_idx]
                opr_n = '('

                if opr.count('(') == 1: # format (a)
                    opr_n += f'(({opr}+1)*({signals_3d[signal][1]})*({signals_3d[signal][2]}))-1 downto ({signals_3d[signal][1]})*({signals_3d[signal][2]})*({opr})'
                elif opr.count(')(') == 1: # format (a)(b)
                    opr = extr_pare_cont_a2d(opr)

                    opr_n += f'(({opr[1]}+1)*({signals_3d[signal][2]}))-1 + ({opr[0]})*({signals_3d[signal][1]})*({signals_3d[signal][2]}) downto ({signals_3d[signal][2]})*({opr[1]}) + ({opr[0]})*({signals_3d[signal][1]})*({signals_3d[signal][2]})'
                else: # format (a)(b)(c)
                    opr = extr_pare_cont_a2d(opr)

                    if not 'downto' in opr[2]:
                        opr_n += f'({opr[0]})*({signals_3d[signal][1]})*({signals_3d[signal][2]}) + ({opr[1]})*({signals_3d[signal][2]}) + {opr[2]}'
                    else:
                        opr_2 = opr[2].split('downto', 1)
                        opr_n += f'{opr_2[0]} + ({opr[0]})*({signals_3d[signal][1]})*({signals_3d[signal][2]}) + ({opr[1]})*({signals_3d[signal][2]}) downto {opr_2[1]} + ({opr[0]})*({signals_3d[signal][1]})*({signals_3d[signal][2]}) + ({opr[1]})*({signals_3d[signal][2]})'

                opr_n += ')'

                parsed_l = parsed_l[:i_idx] + opr_n + parsed_l[f_idx:]

    if ';' in line and not ';' in parsed_l:
        parsed_l += ';'
    return parsed_l


with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
    for line in infile:
        processed_line = line
        signal_name = line

        if 'array_2d' in line or 'array_3d' in line:
            # Extracting signal name
            signal_name = signal_name.replace('signal ', '').split()[0].strip()

            if 'array_2d' in line:
                signals_2d[signal_name] = []
                type_2d = True
            elif 'array_3d' in line:
                signals_3d[signal_name] = []
                type_2d = False

            # Changing signal definitions
            idx = extr_pare_cont(line)
            processed_line = processed_line[:processed_line.index('array_')]

            signal_size = ''

            for i in idx:
                i = parser_idx(i)
                signal_size += f'({i})*'

                if type_2d:
                    signals_2d[signal_name].append(i)
                else:
                    signals_3d[signal_name].append(i)

            processed_line += f'std_logic_vector(({signal_size[:-1]})-1 downto 0)'

            if ';' in line:
                processed_line += ';'
        else:
            processed_line = parser_line(processed_line)


        processed_line = processed_line.replace('\n', '')
        outfile.write(processed_line + '\n')