import numpy as np
from pathlib import Path

i = 1
newfolder = Path("custom_testcase_" + str(i))
while (newfolder.is_dir()):
    newfolder = Path("custom_testcase_" + str(i))
    i += 1
newfolder.mkdir()

print("N is the number of states required")
N = input("Provide N (or ENTER for random): ").strip()

N = np.random.randint(1, 31) if (N=='') else int(N)
print("Value of N:", N)
if (N>31): 
    raise ValueError("N cannot be more than 31")

print("M is the number of possible observations required")
M = input("Provide M (or ENTER for random): ").strip()

M = np.random.randint(1, 1024//N) if (M=='') else int(M)
print("Value of M:", M)
if (int(N)*int(M) > 1024):
    raise ValueError(f"Invalid combination. NxM(={N*M}) cannot be more than 1024")

st_tr_matrix = np.log(np.random.rand((N+1) * N)).astype(np.float32)
em_matrix = np.log(np.random.rand(N * M)).astype(np.float32)

num_inps = input("Provide no. of input vectors required (or ENTER for random): ")
num_inps = np.random.randint(1, 50) if (num_inps=='') else int(num_inps)
print("Number of input vectors:", num_inps)

max_len = input("Provide maximum length of input sequence (or ENTER for random): ")
max_len = np.random.randint(1, 1024//N) if (max_len=='') else int(max_len)
print("Maximum length of a input sequence (max_len) is:", max_len)

if (max_len*N > 1024):
    raise ValueError(f"Invalid combination. max_len*N(={max_len*N}) cannot be more than 1024")


new_path = Path.joinpath(Path.cwd(), newfolder)

with (open(Path.joinpath(new_path, "N.dat"), 'w') as fn,
      open(Path.joinpath(new_path, "A.dat"), 'w') as fa,
      open(Path.joinpath(new_path, "B.dat"), 'w') as fb,
      open(Path.joinpath(new_path, "input.dat"), 'w') as fin):

    fn.writelines(f"{i[2:]}\n" for i in map(hex, [N, M]))
    fa.writelines(f"{val:08x}\n" for val in st_tr_matrix.view(np.uint32))
    fb.writelines(f"{val:08x}\n" for val in em_matrix.view(np.uint32))
    for inp in range(num_inps): 
        seq = np.random.randint(low=1, high=M+1, 
                                size=np.random.randint(1, max_len+1))
        fin.write('\n'.join(f"{hex(i)[2:].upper()}" for i in seq.view(np.uint32)))
        fin.write('\nFFFFFFFF\n')
    fin.write('0\n')

print("Custom test case files are saved in", new_path)
