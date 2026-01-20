import numpy as np
from pathlib import Path

# NM_FILE_PATH = Path("huge\N_huge.dat")
# TR_MAT_PATH = Path("huge\A_huge.dat")
# EM_MAT_PATH = Path("huge\B_huge.dat")
# INP_FILE_PATH = Path("huge\input_huge.dat")

NM_FILE_PATH = Path(input("N.dat file path: ").strip())
TR_MAT_PATH = Path(input("transimssion matrix file path: ").strip())
EM_MAT_PATH = Path(input("emission matrix file path: ").strip())
INP_FILE_PATH = Path(input("input file path: ").strip())

with (open(NM_FILE_PATH, 'r') as f_nm,
      open(TR_MAT_PATH, 'r') as f_tr, 
      open(EM_MAT_PATH, 'r') as f_em,
      open(INP_FILE_PATH, 'r') as f_ip):
    
    N, M = map(lambda i: int(i, 16), \
               f_nm.read().splitlines())
    tr_matrix = np.array(f_tr.read().splitlines())
    em_matrix = np.array(f_em.read().splitlines())
    inp = f_ip.read().splitlines()

ieee2float = lambda i : np.uint32(int(i, base=16)).view(np.float32)

tr_matrix = np.vectorize(ieee2float)(tr_matrix)
init_prob = np.array(tr_matrix[:N])
tr_matrix =  np.reshape(tr_matrix[N:], [N, N])

em_matrix = np.vectorize(ieee2float)(em_matrix)
em_matrix = np.reshape(em_matrix, [N, M])


def viterbi(input_seq):
    
    T = len(input_seq)
    result = np.zeros(T, dtype=np.int32)
    trcbk_matrix = np.zeros((T, N), dtype=np.int32)
    
    vt = init_prob + em_matrix[:, input_seq[0]-1]
    trcbk_matrix[0] = np.argmax(np.tile(init_prob[:, None], (1, N)), axis=0)
    prev_vt = vt
    
    for i in range(1, T):
        vt = prev_vt[:, None] + tr_matrix + em_matrix[:, input_seq[i]-1]
        trcbk_matrix[i] = np.argmax(vt, axis=0)
        prev_vt = np.max(vt, axis=0)

    max_index = np.argmax(prev_vt)
    result[T-1] = max_index
    for i in range(T-2, -1, -1):
        result[i] = trcbk_matrix[i+1, max_index]
        max_index = result[i]
        
    result = np.vectorize(lambda i: hex(i+1)[2:])(result)

    return (result, max(prev_vt))

inp_seq = []

i = 1
outfilepath = Path("py_output_" + str(i) + ".dat")
while (outfilepath.is_dir()):
    outfilepath = Path("py_output_" + str(i) + ".dat")
    i += 1
outfilepath.touch()

with open(outfilepath, 'w') as outfile:
    for i in inp:
        if (i=='FFFFFFFF'):
            result, maxx = viterbi(inp_seq)
            outfile.write("\n".join(f"{int(r, 16):08x}" for r in result) + '\n')
            outfile.write(f"{maxx.view(np.uint32):08x}\n")
            outfile.write(8*'f' + '\n')
            inp_seq.clear()
        elif (i=='0'): 
            outfile.write(8*'0' + '\n')
            break
        else:
            inp_seq.append(int(i, base=16))

print("Output file saved at", Path.joinpath(Path.cwd(), outfilepath))

