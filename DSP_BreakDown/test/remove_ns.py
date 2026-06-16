### split conv_and_mul.txt into two files, one for inputs and one for outputs
################################################################
# in_signals = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
#               12, 13, 14, 18, 19, 20, 21, 22, 23,
#               24, 25, 26, 27, 28, 29, 31, 32, 33, 34]
# out_signals = [15, 16, 17, 30, 35, 36, 37, 38, 39,
#                40, 41, 42, 43, 44, 45, 46]
# in_file_text = ""
# out_file_text = ""
# line_count = 0
# with open ("conv_and_mul.txt") as f:
#     for line in f:
#         line_words = line.split()
#         for i in range(len(line_words)):
#             if i+1 in in_signals:
#                 in_file_text += line_words[i] + " "
#             elif i+1 in out_signals:
#                 out_file_text += line_words[i] + " "
#         in_file_text += "\n"
#         out_file_text += "\n"
#         line_count += 1
#         print(line_count)

# with open (f"conv_and_mul_in.txt", "w") as f:
#     f.write(in_file_text)
# with open (f"conv_and_mul_out.txt", "w") as f:
#     f.write(out_file_text)

### edit signal values in the txt file
#################################################################
signal_index = 19
file_name = "conv_and_mul_in.txt"
signal_new_value = "0000"
new_text = ""
line_count = 0
with open(file_name, "r") as f:
    for line in f:
        line_count += 1
        line_words = line.split()
        line_words[signal_index] = str(signal_new_value)
        new_text += " ".join(line_words)+ "\n"
        if line_count % 5000 == 0:
            print(f"Processed {line_count} lines")
with open(file_name, "w") as f:
    f.write(new_text)