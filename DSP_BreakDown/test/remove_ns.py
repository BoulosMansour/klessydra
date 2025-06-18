new_file_text = ""
i = 0
file_number = 0
with open ("conv_matmul_shift_comp.txt") as f:
    for line in f:
        i+=1
        line_words = line.split()
        if len(line_words) > 18:
            if line_words[16] == "0":
                line_words[16] = "00000000"
                line_words[17] = "00000000"
        # if 'ns' in line_words:
        #     line_words.remove('ns')
        new_file_text += " ".join(line_words) + "\n"
        if i % 70000 == 0:
            print(f"Processed {i} lines")
            file_number += 1
            with open (f"conv_matmul_shift_comp_{file_number}.txt", "w") as f:
                f.write(new_file_text)
            new_file_text = ""

with open (f"conv_matmul_shift_comp_{file_number+1}.txt", "w") as f:
    f.write(new_file_text)