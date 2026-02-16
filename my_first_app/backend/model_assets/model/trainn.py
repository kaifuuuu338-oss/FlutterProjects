import pandas as pd
import numpy as np

# Number of samples per category
num_low = 600
num_medium = 200
num_high = 200

rows = []

# Function to generate child_id
def generate_child_id(num):
    return f"AP_ECD_{num:06d}"

# LOW (score 0–10)
for i in range(1, num_low + 1):
    child_id = generate_child_id(i)
    score = np.random.randint(0, 11)
    category = "Low"
    rows.append([child_id, score, category])

# MEDIUM (score 11–25)
for i in range(num_low + 1, num_low + num_medium + 1):
    child_id = generate_child_id(i)
    score = np.random.randint(11, 26)
    category = "Medium"
    rows.append([child_id, score, category])

# HIGH (score 26–35)
for i in range(num_low + num_medium + 1, num_low + num_medium + num_high + 1):
    child_id = generate_child_id(i)
    score = np.random.randint(26, 36)
    category = "High"
    rows.append([child_id, score, category])

# Create DataFrame
df = pd.DataFrame(rows, columns=[
    "child_id",
    "baseline_score",
    "baseline_category"
])

# Save Excel file
df.to_excel("Baseline_Risk_600_200_200.xlsx", index=False)

# Show counts
print("Dataset created successfully!")
print(df['baseline_category'].value_counts())
print("Total rows:", len(df))
