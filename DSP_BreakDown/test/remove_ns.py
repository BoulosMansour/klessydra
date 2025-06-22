new_file_text = ""
with open ("conv_matmul_shift_comp.txt") as f:
    for line in f:
        for letter in line:
            if letter == 'X' or letter == 'U':
                new_file_text += '0'
            else:
                new_file_text += letter
        # i+=1
        # line_words = line.split()
        # if len(line_words) > 18:
        #     if line_words[16] == "0":
        #         line_words[16] = "00000000"
        #         line_words[17] = "00000000"
        # if 'ns' in line_words:
        #     line_words.remove('ns')
        # new_file_text += " ".join(line_words) + "\n"

with open (f"conv_matmul_shift_comp.txt", "w") as f:
    f.write(new_file_text)