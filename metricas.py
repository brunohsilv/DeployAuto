import pandas as pd

df = pd.read_csv("benchmarks/all_benchmarks.csv")

metrics = df[['terraform_seconds','ansible_seconds','total_seconds']].describe().T
metrics = metrics[['count','mean','50%','min','max','std']]
metrics.rename(columns={'50%':'median'}, inplace=True)

print("\n===== MÉTRICAS ESTATÍSTICAS =====")
print(metrics)
