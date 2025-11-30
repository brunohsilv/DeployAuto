import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

# Criar pasta para imagens
os.makedirs("benchmark_images", exist_ok=True)

# Ler CSV consolidado
df = pd.read_csv("benchmarks/all_benchmarks.csv")

# Gráfico 1: Tempo Total por execução (barplot)
plt.figure(figsize=(10,5))
sns.barplot(x='run_id', y='total_seconds', data=df, palette="Blues")
plt.title("Tempo Total por Execução do Pipeline")
plt.xlabel("Execução")
plt.ylabel("Tempo Total (s)")
plt.savefig("benchmark_images/tempo_total_por_execucao.png")
plt.close()

# Gráfico 2: Boxplot do tempo total
plt.figure(figsize=(8,5))
sns.boxplot(y='total_seconds', data=df, palette="Pastel1")
plt.title("Distribuição do Tempo Total do Pipeline")
plt.ylabel("Tempo Total (s)")
plt.savefig("benchmark_images/boxplot_tempo_total.png")
plt.close()

# Gráfico 3: Linha do tempo total por execução
plt.figure(figsize=(10,5))
sns.lineplot(x='run_id', y='total_seconds', data=df, marker='o', color='green')
plt.title("Evolução do Tempo Total do Pipeline")
plt.xlabel("Execução")
plt.ylabel("Tempo Total (s)")
plt.xticks(rotation=45)
plt.grid(True)
plt.tight_layout()
plt.savefig("benchmark_images/linha_evolucao_tempo_total.png")
plt.close()

print("Gráficos gerados em: benchmark_images/")
