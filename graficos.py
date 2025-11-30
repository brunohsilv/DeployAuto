import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

os.makedirs("benchmark_images", exist_ok=True)
df = pd.read_csv("benchmarks/all_benchmarks.csv")

# Gráfico 1: Tempo Total por execução
plt.figure(figsize=(10,5))
sns.barplot(x='run_id', y='total_seconds', data=df, palette="Blues")
plt.title("Tempo Total por Execução")
plt.xlabel("Execução")
plt.ylabel("Tempo Total (s)")
plt.savefig("benchmark_images/tempo_total_por_execucao.png")
plt.close()

# Gráfico 2: Terraform vs Ansible
df_melt = df.melt(id_vars='run_id', value_vars=['terraform_seconds','ansible_seconds'])
plt.figure(figsize=(10,5))
sns.barplot(x='run_id', y='value', hue='variable', data=df_melt, palette="Set2")
plt.title("Comparação Terraform vs Ansible")
plt.xlabel("Execução")
plt.ylabel("Tempo (s)")
plt.savefig("benchmark_images/terraform_vs_ansible.png")
plt.close()

# Gráfico 3: Boxplot
plt.figure(figsize=(10,5))
sns.boxplot(data=df[['terraform_seconds','ansible_seconds','total_seconds']], palette="Pastel1")
plt.title("Distribuição dos Tempos")
plt.savefig("benchmark_images/boxplot_tempos.png")
plt.close()

print("Gráficos gerados em: benchmark_images/")
