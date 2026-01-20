from pathlib import Path

file1 = Path(input("Provide path to file1: ").strip())
file2 = Path(input("Provide path to file2: ").strip())

# file1 = Path("test-cases/output_1.dat")
# file2 = Path("test-cases/")

with open(file1) as f1, open(file2) as f2:
    lines1 = f1.readlines()
    lines2 = f2.readlines()

error_count = 0

for i, (l1, l2) in enumerate(zip(lines1, lines2), start=1):
    if (l1 != l2):
        error_count += 1
        print(f"Difference at line {i}:")
        print("file1:", l1.strip())
        print("file2:", l2.strip())

if (error_count==0):
    print("\nFiles match perfectly")
else:
    print("\nFiles are NOT matched")
    if len(lines1) != len(lines2):
        error_count += abs(len(lines1)-len(lines2))
        print("Files have different number of lines")

print("Number of mismatched lines:", error_count)
    