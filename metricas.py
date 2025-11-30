import pandas as pd
import os

# Criar pasta para métricas
os.makedirs("metrics", exist_ok=True)

# Ler CSV consolidado
df = pd.read_csv("benchmarks/all_benchmarks.csv")

# Calcular métricas estatísticas
metrics = df[['total_seconds']].describe().T
metrics = metrics[['count','mean','50%','min','max','std']]

# Traduzir colunas para português
metrics.rename(columns={
    'count': 'quantidade',
    'mean': 'média',
    '50%': 'mediana',
    'min': 'mínimo',
    'max': 'máximo',
    'std': 'desvio_padrao'
}, inplace=True)

# Salvar métricas em CSV
metrics_csv_file = "metrics/resumo_metricas.csv"
metrics.to_csv(metrics_csv_file, index=True)

# Salvar métricas em TXT
metrics_txt_file = "metrics/resumo_metricas.txt"
with open(metrics_txt_file, "w") as f:
    f.write("===== MÉTRICAS ESTATÍSTICAS DO PIPELINE =====\n\n")
    f.write(metrics.to_string())
    f.write("\n")

# Exibir na tela
print("\n===== MÉTRICAS ESTATÍSTICAS =====")
print(metrics)
print(f"\nMétricas salvas em CSV: {metrics_csv_file}")
print(f"Métricas salvas em TXT: {metrics_txt_file}")
