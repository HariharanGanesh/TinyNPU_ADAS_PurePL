import matplotlib.pyplot as plt
import numpy as np

# Set IEEE paper styling
plt.rcParams['font.family'] = 'serif'
try:
    plt.rcParams['font.serif'] = ['Times New Roman'] + plt.rcParams['font.serif']
except:
    pass
plt.rcParams['font.size'] = 12
plt.rcParams['axes.labelsize'] = 14
plt.rcParams['axes.titlesize'] = 16
plt.rcParams['xtick.labelsize'] = 12
plt.rcParams['ytick.labelsize'] = 12
plt.rcParams['legend.fontsize'] = 12
plt.rcParams['figure.dpi'] = 300

# --- Graph 1: Resource Utilization ---
labels = ['LUTs', 'DSPs', 'BRAM (36Kb)']
standalone = [29236, 150, 2]
soc = [13632, 220, 21.5]

x = np.arange(len(labels))
width = 0.35

fig, ax = plt.subplots(figsize=(8, 6))
rects1 = ax.bar(x - width/2, standalone, width, label='Standalone NPU', color='#1f77b4', edgecolor='black')
rects2 = ax.bar(x + width/2, soc, width, label='SoC ADAS Wrapper', color='#ff7f0e', edgecolor='black')

ax.set_ylabel('Resource Count (Log Scale)')
ax.set_title('FPGA Resource Utilization (Zynq-7020)')
ax.set_xticks(x)
ax.set_xticklabels(labels)
ax.legend()
ax.set_yscale('log')
ax.grid(True, which="both", ls="--", alpha=0.5)

def autolabel(rects):
    for rect in rects:
        height = rect.get_height()
        ax.annotate(f'{height}',
                    xy=(rect.get_x() + rect.get_width() / 2, height),
                    xytext=(0, 3),  # 3 points vertical offset
                    textcoords="offset points",
                    ha='center', va='bottom', fontsize=10)

autolabel(rects1)
autolabel(rects2)

fig.tight_layout()
plt.savefig('fig1_resource_utilization.png', dpi=600)
plt.close()

# --- Graph 2: Power Breakdown ---
labels_power = ['Dynamic Power\n(0.990 W)', 'Static Power\n(0.125 W)']
sizes = [0.990, 0.125]
colors = ['#2ca02c', '#d62728']
explode = (0.1, 0)  # explode 1st slice

fig2, ax2 = plt.subplots(figsize=(6, 6))
ax2.pie(sizes, explode=explode, labels=labels_power, colors=colors, autopct='%1.1f%%',
        shadow=True, startangle=140, textprops={'fontsize': 14})
ax2.axis('equal')
ax2.set_title('SoC Total On-Chip Power (1.114 W)')

plt.savefig('fig2_power_breakdown.png', dpi=600)
plt.close()

# --- Graph 3: Performance Metrics ---
labels_perf = ['Peak GOPS\n(Target 125 MHz)', 'Peak GOPS\n(Fmax 127.94 MHz)', 'Sustained Effective\nGOPS']
values_perf = [31.50, 32.24, 26.77]

fig3, ax3 = plt.subplots(figsize=(8, 6))
bars = ax3.bar(labels_perf, values_perf, color=['#9467bd', '#8c564b', '#e377c2'], edgecolor='black', width=0.6)

ax3.set_ylabel('Giga-Operations Per Second (GOPS)')
ax3.set_title('Performance Metrics (INT8 Inference)')
ax3.set_ylim(0, 40)
ax3.grid(axis='y', linestyle='--', alpha=0.7)

for bar in bars:
    yval = bar.get_height()
    ax3.text(bar.get_x() + bar.get_width()/2, yval + 0.5, f'{yval:.2f}', ha='center', va='bottom', fontweight='bold')

fig3.tight_layout()
plt.savefig('fig3_performance_metrics.png', dpi=600)
plt.close()
print("Graphs generated successfully.")
